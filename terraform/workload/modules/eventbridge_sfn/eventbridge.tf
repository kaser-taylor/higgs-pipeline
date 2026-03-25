###############################################################################
# Eventing: S3 → EventBridge → Step Functions
# File: eventbridge.tf
#
# Configures the trigger chain that starts the pipeline. An EventBridge rule
# watches for new objects under the ingestion prefix of the S3 data bucket
# (looked up in data.tf), then starts the state machine defined in
# step_functions.tf. Includes a DLQ for failed deliveries and the IAM role
# that grants EventBridge permission to invoke Step Functions.
###############################################################################

# ─── Dead-Letter Queue ────────────────────────────────────────────────────────

resource "aws_sqs_queue" "eventbridge_dlq" {
  name = "${local.name_prefix}-eventbridge-dlq"

  # Messages that fail delivery sit here up to 4 days so we can inspect them.
  message_retention_seconds = 345600 # 4 days

  tags = local.tags
}

# Allow EventBridge to send failed-delivery messages to the DLQ.
resource "aws_sqs_queue_policy" "eventbridge_dlq" {
  queue_url = aws_sqs_queue.eventbridge_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.eventbridge_dlq.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.raw_uploads.arn
          }
        }
      }
    ]
  })
}

# ─── EventBridge Rule ─────────────────────────────────────────────────────────

resource "aws_cloudwatch_event_rule" "raw_uploads" {
  name        = "${local.name_prefix}-raw-uploads"
  description = "Start the Higgs pipeline when a new object lands under the ingestion/ prefix."

  # Boolean kill switch — set pipeline_enabled=false to stop all pipeline triggers
  # without destroying infrastructure.
  state = var.pipeline_enabled ? "ENABLED" : "DISABLED"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [data.aws_s3_bucket.data.bucket]
      }
      object = {
        key = [{ prefix = var.ingestion_prefix }]
      }
    }
  })

  tags = local.tags
}

# ─── EventBridge → Step Functions Target ─────────────────────────────────────

resource "aws_cloudwatch_event_target" "start_sfn" {
  rule     = aws_cloudwatch_event_rule.raw_uploads.name
  arn      = aws_sfn_state_machine.higgs_pipeline.arn
  role_arn = aws_iam_role.eventbridge_invoke_sfn.arn

  # Shape the raw S3 event into a clean, stable payload before it enters
  # Step Functions. This makes state machine input deterministic and replay-safe.
  input_transformer {
    input_paths = {
      bucket     = "$.detail.bucket.name"
      key        = "$.detail.object.key"
      etag       = "$.detail.object.etag"
      size       = "$.detail.object.size"
      version_id = "$.detail.object.version-id"
      event_time = "$.time"
    }

    # The template produces the exact shape expected by the CheckAlreadyProcessed
    # Lambda. Every downstream state receives this root payload.
    input_template = <<-TEMPLATE
      {
        "bucket":     <bucket>,
        "key":        <key>,
        "etag":       <etag>,
        "size":       <size>,
        "version_id": <version_id>,
        "event_time": <event_time>
      }
    TEMPLATE
  }

  # Retry + DLQ: EventBridge will retry for up to 1 hour (10 attempts) before
  # parking the undeliverable event on the DLQ for later inspection or replay.
  retry_policy {
    maximum_event_age_in_seconds = 3600
    maximum_retry_attempts       = 10
  }

  dead_letter_config {
    arn = aws_sqs_queue.eventbridge_dlq.arn
  }
}

# ─── IAM: EventBridge → Step Functions Invocation Role ───────────────────────

data "aws_iam_policy_document" "eventbridge_assume" {
  statement {
    sid     = "AllowEventBridgeAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_invoke_sfn" {
  name               = "${local.name_prefix}-events-start-sfn"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume.json
  description        = "Allows EventBridge to start the Higgs pipeline state machine. Nothing else."

  tags = local.tags
}

data "aws_iam_policy_document" "eventbridge_start_sfn" {
  statement {
    sid     = "StartHiggsStateMachineOnly"
    effect  = "Allow"
    actions = ["states:StartExecution"]

    # Scoped to this one state machine — not states:* on *.
    resources = [aws_sfn_state_machine.higgs_pipeline.arn]
  }
}

resource "aws_iam_role_policy" "eventbridge_start_sfn" {
  name   = "start-sfn-execution"
  role   = aws_iam_role.eventbridge_invoke_sfn.id
  policy = data.aws_iam_policy_document.eventbridge_start_sfn.json
}
