# sets the terraform version and provider markup
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.62.0"
    }
  }
}

# sets the provider and the region in the provider
provider "aws" {
  region  = var.region
  profile = "higgs-pipeline"
}

/* 
Introspection

sets account access and region
*/

# sets data block type to my caller identity, this is where sso comes in. terraform 
# terraform looks at the aws cli for credentials 

data "aws_caller_identity" "me" {}
data "aws_region" "current" {}

/* 
s3 Block Public Access (ACCOUNT-WIDE)
*/

resource "aws_s3_account_public_access_block" "account" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}


/*
CloudTrail (multi-region) + secure s3 Bucket
*/

# creates s3 bucket named higgs, var env, cloudtrail, aws id

resource "aws_s3_bucket" "cloudtrail" {
  bucket        = "higgs-${var.env}-cloudtrail-${data.aws_caller_identity.me.account_id}"
  force_destroy = true

}

# enables versioning on the bucket and nicknames it trail
resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration { status = "Enabled" }

}

# blocks and prevents any public access on the bucket
resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true

}

# sets server side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# this section allows cloudtrail to write to the bucket

# first we create a json policy document that is then fed to a resource
data "aws_iam_policy_document" "trail_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.cloudtrail.bucket}/AWSLogs/${data.aws_caller_identity.me.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
  }
}

# then we apply the policy

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.trail_bucket_policy.json
}

resource "aws_cloudtrail" "main" {
  name                          = "higgs-${var.env}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = false
}

/*
Aws budgeting section
*/

resource "aws_budgets_budget" "monthly" {
  name         = "monthly-cap-${var.env}"
  budget_type  = "COST"
  limit_amount = var.monthly_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }


  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}


# Variables

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "alert_email" {
  type = string
}

variable "monthly_limit_usd" {
  type    = string
  default = "5"
}



