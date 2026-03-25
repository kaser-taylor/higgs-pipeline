###############################################################################
# Data Sources & Locals
# File: data.tf
#
# Read-only lookups for the S3 data bucket (data-foundation) and the six
# pipeline Lambda functions invoked by step_functions.tf. Also defines the
# shared name_prefix local and tag map used across all files in this module.
###############################################################################

# ─── Caller identity (used for scope conditions in IAM trust policies) ────────

data "aws_caller_identity" "me" {}

data "aws_region" "current" {}

# ─── S3 data bucket (created in data-foundation) ────────────────────────────
#
# Looked up by name so this module can be applied independently of the
# data-foundation module.

data "aws_s3_bucket" "data" {
  bucket = "higgs-${var.env}-data-${data.aws_caller_identity.me.account_id}"
}

# ─── Lambda function references ───────────────────────────────────────────────
#
# The six Lambdas invoked by the state machine in step_functions.tf. Stub
# functions must be deployed first so this module applies cleanly. Replace
# with direct resource references once the Lambda modules share this root.

data "aws_lambda_function" "check_state" {
  function_name = "${local.name_prefix}-check-state"
}

data "aws_lambda_function" "etl" {
  function_name = "${local.name_prefix}-etl"
}

data "aws_lambda_function" "predict" {
  function_name = "${local.name_prefix}-predict"
}

data "aws_lambda_function" "load_redshift" {
  function_name = "${local.name_prefix}-load-redshift"
}

data "aws_lambda_function" "mark_done" {
  function_name = "${local.name_prefix}-mark-done"
}

data "aws_lambda_function" "mark_failed" {
  function_name = "${local.name_prefix}-mark-failed"
}


