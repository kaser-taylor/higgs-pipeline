###############################################################################
# Outputs
# File: outputs.tf
#
# Exposes the ARNs and names of all resources created in eventbridge.tf and
# step_functions.tf for consumption by other modules or the CI pipeline.
###############################################################################

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule that triggers the pipeline on ingestion/ uploads."
  value       = aws_cloudwatch_event_rule.raw_uploads.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule."
  value       = aws_cloudwatch_event_rule.raw_uploads.arn
}

output "eventbridge_dlq_url" {
  description = "SQS URL of the EventBridge dead-letter queue. Use this to inspect or replay failed events."
  value       = aws_sqs_queue.eventbridge_dlq.url
}

output "eventbridge_dlq_arn" {
  description = "ARN of the EventBridge dead-letter queue."
  value       = aws_sqs_queue.eventbridge_dlq.arn
}

output "sfn_state_machine_arn" {
  description = "ARN of the Higgs pipeline Step Functions Express state machine."
  value       = aws_sfn_state_machine.higgs_pipeline.arn
}

output "sfn_state_machine_name" {
  description = "Name of the Step Functions state machine."
  value       = aws_sfn_state_machine.higgs_pipeline.name
}

output "sfn_log_group_name" {
  description = "CloudWatch log group receiving Step Functions execution logs."
  value       = aws_cloudwatch_log_group.sfn_logs.name
}

output "sfn_exec_role_arn" {
  description = "IAM role ARN used by Step Functions to invoke Lambdas, write logs, and emit X-Ray traces."
  value       = aws_iam_role.sfn_exec.arn
}

output "eventbridge_sfn_role_arn" {
  description = "IAM role ARN that allows EventBridge to call states:StartExecution on the pipeline."
  value       = aws_iam_role.eventbridge_invoke_sfn.arn
}

output "pipeline_kill_switch_status" {
  description = "Current state of the pipeline kill switch variable."
  value       = var.pipeline_enabled ? "ENABLED — EventBridge rule is active." : "DISABLED — EventBridge rule is inactive. No new executions will start."
}
