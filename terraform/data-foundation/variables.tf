variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "Optional AWS CLI profile name (SSO profile name, etc). Leave empty to use env vars/instance role."
  default     = ""
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

variable "bucket_name" {
  type        = string
  description = "Globally-unique S3 bucket name."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be a valid S3 bucket name (lowercase, 3-63 chars, letters/numbers/dot/hyphen)."
  }
}

variable "ingestion_prefix" {
  type        = string
  description = "Prefix (folder-like path) for raw ingested data."
  default     = "ingestion/"

  validation {
    condition     = !startswith(var.ingestion_prefix, "/")
    error_message = "ingestion_prefix must not start with '/'."
  }
}

variable "cleaned_prefix" {
  type        = string
  description = "Prefix (folder-like path) for cleaned outputs."
  default     = "cleaned/"

  validation {
    condition     = !startswith(var.cleaned_prefix, "/")
    error_message = "cleaned_prefix must not start with '/'."
  }
}

variable "lifecycle_days" {
  type        = number
  description = "Days before objects (and versions, if any) are deleted."
  default     = 60

  validation {
    condition     = var.lifecycle_days >= 1
    error_message = "lifecycle_days must be >= 1."
  }
}

variable "force_destroy" {
  type        = bool
  description = "If true, Terraform can destroy the bucket even if it contains objects (useful in dev; risky in prod)."
  default     = false
}

variable "etl_lambda_role_name" {
  type        = string
  description = "Existing IAM role name used by the ETL Lambda function."
}

variable "predictions_role_name" {
  type        = string
  description = "Existing IAM role name used by the predictions container runtime (e.g., ECS task role)."
}
