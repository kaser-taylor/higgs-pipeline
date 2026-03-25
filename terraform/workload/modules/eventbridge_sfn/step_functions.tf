###############################################################################
# Orchestration: Step Functions Express State Machine
# File: step_functions.tf
#
# Defines the Higgs pipeline state machine and its IAM execution role. The
# machine is triggered by the EventBridge rule in eventbridge.tf and invokes
# the six Lambda functions referenced in data.tf to run idempotency checks,
# ETL, inference, and Redshift loading, with failure handling throughout.
###############################################################################

# ─── CloudWatch Log Group ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/states/${local.name_prefix}-pipeline"
  retention_in_days = 30 # balances observability with log ingestion cost

  tags = local.tags
}

# ─── Step Functions Express State Machine ────────────────────────────────────

resource "aws_sfn_state_machine" "higgs_pipeline" {
  name = "${local.name_prefix}-pipeline"
  type = "EXPRESS" # cheap, high-throughput; max 5 min per execution

  role_arn = aws_iam_role.sfn_exec.arn

  # ── State machine definition (Amazon States Language) ─────────────────────
  #
  # Flow:
  #   CheckAlreadyProcessed → AlreadyDone? ──(LOAD_DONE)──→ AlreadyProcessedSucceed
  #                                         ──(else)──────→ ETL → Predict → LoadRedshift
  #                                                                            → MarkLoadDone
  #   Any task failure → MarkFailed → PipelineFailed
  #
  definition = jsonencode({
    Comment = "Higgs ML inference pipeline: check idempotency, ETL, predict, load Redshift."
    StartAt = "CheckAlreadyProcessed"

    States = {

      # ── Guard: short-circuit if this content hash was already fully loaded ──
      CheckAlreadyProcessed = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = local.lambda_check_state.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.check"
        Next       = "AlreadyDone"

        # Lambda service errors only — we let application errors bubble to Catch below.
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException", "Lambda.SdkClientException"]
            IntervalSeconds = 3
            MaxAttempts     = 4
            BackoffRate     = 2.0
            JitterStrategy  = "FULL"
          }
        ]

        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "MarkFailed"
            ResultPath  = "$.error"
          }
        ]
      }

      # ── Choice: already done? ─────────────────────────────────────────────
      AlreadyDone = {
        Type = "Choice"
        Choices = [
          {
            # CheckAlreadyProcessed Lambda returns {status: "LOAD_DONE"} when
            # this content hash has already been fully processed.
            Variable     = "$.check.Payload.status"
            StringEquals = "LOAD_DONE"
            Next         = "AlreadyProcessedSucceed"
          },
          {
            # If a previous run failed, don't auto-retry. Cost control: operator
            # must explicitly acknowledge and reprocess via manual replay.
            Variable     = "$.check.Payload.status"
            StringEquals = "FAILED"
            Next         = "PreviouslyFailed"
          }
        ]
        # All other statuses (RECEIVED, ETL_DONE, PRED_DONE, or pk not found)
        # proceed to ETL to run the pipeline normally.
        Default = "ETL"
      }

      AlreadyProcessedSucceed = {
        Type    = "Succeed"
        Comment = "Content hash already in LOAD_DONE state — skipping duplicate run."
      }

      # ── Guard: reject auto-retry of previously failed uploads ─────────────
      PreviouslyFailed = {
        Type  = "Fail"
        Error = "PreviouslyFailedUpload"
        Cause = "This content hash was previously processed and failed. Check DynamoDB state record for error details. Manual replay required."
      }

      # ── ETL Lambda ────────────────────────────────────────────────────────
      ETL = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = local.lambda_etl.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.etl"

        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException", "Lambda.SdkClientException"]
            IntervalSeconds = 3
            MaxAttempts     = 4
            BackoffRate     = 2.0
            JitterStrategy  = "FULL"
          }
        ]

        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "MarkFailed"
            ResultPath  = "$.error"
          }
        ]

        Next = "Predict"
      }

      # ── Inference Lambda ──────────────────────────────────────────────────
      Predict = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = local.lambda_predict.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.pred"

        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException", "Lambda.SdkClientException"]
            IntervalSeconds = 3
            MaxAttempts     = 4
            BackoffRate     = 2.0
            JitterStrategy  = "FULL"
          }
        ]

        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "MarkFailed"
            ResultPath  = "$.error"
          }
        ]

        Next = "LoadRedshift"
      }

      # ── Load Lambda ───────────────────────────────────────────────────────
      LoadRedshift = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = local.lambda_load_redshift.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.load"

        # Longer initial interval: Redshift Serverless may be resuming from
        # auto-pause, which can take 20-60 seconds.
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.TooManyRequestsException", "Lambda.SdkClientException"]
            IntervalSeconds = 10
            MaxAttempts     = 3
            BackoffRate     = 2.0
            JitterStrategy  = "FULL"
          }
        ]

        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "MarkFailed"
            ResultPath  = "$.error"
          }
        ]

        Next = "MarkLoadDone"
      }

      # ── Mark success in DynamoDB ─────────────────────────────────────────
      MarkLoadDone = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = local.lambda_mark_done.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.done"
        End        = true
      }

      # ── Failure path: record error in DynamoDB, then Fail ────────────────
      MarkFailed = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = local.lambda_mark_failed.arn
          "Payload.$"  = "$"
        }
        ResultPath = "$.failure_record"
        Next       = "PipelineFailed"
      }

      PipelineFailed = {
        Type  = "Fail"
        Error = "PipelineFailed"
        Cause = "A pipeline stage failed. Check the DynamoDB state record and CloudWatch logs for details."
      }
    }
  })

  # ── Logging ────────────────────────────────────────────────────────────────
  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
    include_execution_data = true

    # Use ALL during active development; switch to ERROR before handing off
    # to production to reduce log volume and cost.
    level = var.sfn_log_level
  }

  # ── Tracing ────────────────────────────────────────────────────────────────
  tracing_configuration {
    enabled = true
  }

  tags = local.tags
}

# ─── IAM: Step Functions Execution Role ──────────────────────────────────────

data "aws_iam_policy_document" "sfn_assume" {
  statement {
    sid     = "AllowStepFunctionsAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }

    # Scope assumption to this account + region to prevent confused-deputy
    # attacks across accounts.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.me.account_id]
    }
  }
}

resource "aws_iam_role" "sfn_exec" {
  name               = "${local.name_prefix}-sfn-exec"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
  description        = "Step Functions execution role — Lambda invoke, CloudWatch Logs, X-Ray."

  tags = local.tags
}

# ── Permission 1: Invoke all six pipeline Lambdas ─────────────────────────────

data "aws_iam_policy_document" "sfn_lambda_invoke" {
  statement {
    sid    = "InvokePipelineLambdas"
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      local.lambda_check_state.arn,
      local.lambda_etl.arn,
      local.lambda_predict.arn,
      local.lambda_load_redshift.arn,
      local.lambda_mark_done.arn,
      local.lambda_mark_failed.arn,
      # Include :* qualifier ARNs so Step Functions can invoke versioned aliases
      # without a separate policy update.
      "${local.lambda_check_state.arn}:*",
      "${local.lambda_etl.arn}:*",
      "${local.lambda_predict.arn}:*",
      "${local.lambda_load_redshift.arn}:*",
      "${local.lambda_mark_done.arn}:*",
      "${local.lambda_mark_failed.arn}:*",
    ]
  }
}

resource "aws_iam_role_policy" "sfn_lambda_invoke" {
  name   = "invoke-pipeline-lambdas"
  role   = aws_iam_role.sfn_exec.id
  policy = data.aws_iam_policy_document.sfn_lambda_invoke.json
}

# ── Permission 2: CloudWatch Logs (required for logging_configuration) ────────

data "aws_iam_policy_document" "sfn_logs" {
  statement {
    sid    = "CloudWatchLogsDelivery"
    effect = "Allow"
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
      # PutLogEvents is used by the log delivery subsystem.
      "logs:PutLogEvents",
    ]
    # Log delivery APIs require * resource; the log group ARN restriction only
    # applies to the data-plane actions (PutLogEvents).
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "sfn_logs" {
  name   = "cloudwatch-log-delivery"
  role   = aws_iam_role.sfn_exec.id
  policy = data.aws_iam_policy_document.sfn_logs.json
}

# ── Permission 3: X-Ray tracing ───────────────────────────────────────────────

data "aws_iam_policy_document" "sfn_xray" {
  statement {
    sid    = "XRayTracing"
    effect = "Allow"
    actions = [
      "xray:PutTraceSegments",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "sfn_xray" {
  name   = "xray-tracing"
  role   = aws_iam_role.sfn_exec.id
  policy = data.aws_iam_policy_document.sfn_xray.json
}
