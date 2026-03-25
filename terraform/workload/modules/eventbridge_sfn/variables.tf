###############################################################################
# Variables
# File: variables.tf
#
# All input variables for this module. Covers AWS provider settings, project
# tagging, the pipeline kill switch, the S3 ingestion prefix that must align
# with the data-foundation module, and Step Functions log verbosity.
###############################################################################

variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Optional AWS CLI profile name (SSO profile name, etc). Leave empty to use env vars/instance role."
}

variable "project" {
  type        = string
  description = "Project tag value."
  default     = "data-pipeline"
}

variable "env" {
  type        = string
  description = "Environment tag value (e.g., dev, stage, prod)."
  default     = "dev"
}

variable "extra_tags" {
  type        = map(string)
  description = "Extra tags to apply to all resources."
  default     = {}
}

variable "pipeline_enabled" {
  type        = bool
  default     = true
  description = <<-EOT
    Kill switch for the entire pipeline. When false, the EventBridge rule is
    disabled so no new Step Functions executions are triggered by S3 uploads.
    Set to false to pause the pipeline without destroying infrastructure:

      terraform apply -var="pipeline_enabled=false"

    A second kill switch is setting reserved_concurrent_executions = 0 on the
    Lambda functions, but that's a sledgehammer — prefer this toggle first.
  EOT
}

variable "ingestion_prefix" {
  type        = string
  description = "Prefix (folder-like path) for raw ingested data. Must match the prefix configured in the data-foundation module."
  default     = "ingestion/"

  validation {
    condition     = !startswith(var.ingestion_prefix, "/")
    error_message = "ingestion_prefix must not start with '/'."
  }
}

variable "sfn_log_level" {
  type        = string
  default     = "ERROR"
  description = <<-EOT
    Step Functions CloudWatch log level. Valid values: OFF | ERROR | FATAL | ALL.
    Use ALL during active development (captures every state transition and I/O).
    Switch to ERROR before leaving the account unattended to reduce log volume
    and CloudWatch Logs ingestion cost.
  EOT

  validation {
    condition     = contains(["OFF", "ERROR", "FATAL", "ALL"], var.sfn_log_level)
    error_message = "sfn_log_level must be one of: OFF, ERROR, FATAL, ALL."
  }
}
