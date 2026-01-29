data "aws_caller_identity" "me" {}

data "aws_iam_role" "etl_lambda" {
  name = var.etl_lambda_role_name
}

data "aws_iam_role" "predictions" {
  name = var.predictions_role_name
}

locals {
  # Normalize prefixes so we can safely build ARNs
  ingestion_prefix_trimmed = trim(var.ingestion_prefix, "/")
  cleaned_prefix_trimmed   = trim(var.cleaned_prefix, "/")

  ingestion_prefix_slash = "${local.ingestion_prefix_trimmed}/"
  cleaned_prefix_slash   = "${local.cleaned_prefix_trimmed}/"

  ingestion_objects_arn = "${aws_s3_bucket.data.arn}/${local.ingestion_prefix_trimmed}/*"
  cleaned_objects_arn   = "${aws_s3_bucket.data.arn}/${local.cleaned_prefix_trimmed}/*"
}

resource "aws_s3_bucket" "data" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

# Explicitly ensure versioning is NOT enabled
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Suspended"
  }
}

# Block public access "on all fronts"
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Enforce bucket ownership; ACLs are effectively disabled
resource "aws_s3_bucket_ownership_controls" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Lifecycle: delete objects after N days; also delete noncurrent versions after N days (if versioning ever exists)
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "expire-all-objects-${var.lifecycle_days}-days"
    status = "Enabled"

    filter {}

    expiration {
      days = var.lifecycle_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.lifecycle_days
    }
  }
}

############################
# IAM policies (identity-based)
############################

# ETL Lambda: read ingestion, write cleaned
data "aws_iam_policy_document" "etl_access" {
  statement {
    sid = "ListBucketScopedToPrefixes"
    actions = [
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.data.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        local.ingestion_prefix_slash,
        "${local.ingestion_prefix_slash}*",
        local.cleaned_prefix_slash,
        "${local.cleaned_prefix_slash}*"
      ]
    }
  }

  statement {
    sid = "ReadFromIngestion"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [local.ingestion_objects_arn]
  }

  statement {
    sid = "WriteToCleaned"
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:PutObjectTagging"
    ]
    resources = [local.cleaned_objects_arn]
  }
}

resource "aws_iam_policy" "etl_access" {
  name        = "${var.project}-${var.env}-etl-s3-access"
  description = "ETL Lambda access: read ingestion/, write cleaned/ in ${var.bucket_name}"
  policy      = data.aws_iam_policy_document.etl_access.json
}

resource "aws_iam_role_policy_attachment" "etl_access" {
  role       = data.aws_iam_role.etl_lambda.name
  policy_arn = aws_iam_policy.etl_access.arn
}

# Predictions containers: read cleaned only
data "aws_iam_policy_document" "predictions_access" {
  statement {
    sid = "ListBucketCleanedOnly"
    actions = [
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.data.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        local.cleaned_prefix_slash,
        "${local.cleaned_prefix_slash}*"
      ]
    }
  }

  statement {
    sid = "ReadCleanedOnly"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [local.cleaned_objects_arn]
  }
}

resource "aws_iam_policy" "predictions_access" {
  name        = "${var.project}-${var.env}-predictions-s3-access"
  description = "Predictions runtime access: read cleaned/ in ${var.bucket_name}"
  policy      = data.aws_iam_policy_document.predictions_access.json
}

resource "aws_iam_role_policy_attachment" "predictions_access" {
  role       = data.aws_iam_role.predictions.name
  policy_arn = aws_iam_policy.predictions_access.arn
}

############################
# Bucket policy (resource-based)
############################

data "aws_iam_policy_document" "bucket_policy" {
  # (Optional but sensible) deny non-TLS access
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.data.arn,
      "${aws_s3_bucket.data.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowETLReadIngestionWriteCleaned"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:PutObjectTagging"
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.etl_lambda.arn]
    }

    resources = [
      aws_s3_bucket.data.arn,
      local.ingestion_objects_arn,
      local.cleaned_objects_arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        local.ingestion_prefix_slash,
        "${local.ingestion_prefix_slash}*",
        local.cleaned_prefix_slash,
        "${local.cleaned_prefix_slash}*"
      ]
    }
  }

  statement {
    sid    = "AllowPredictionsReadCleaned"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_role.predictions.arn]
    }

    resources = [
      aws_s3_bucket.data.arn,
      local.cleaned_objects_arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        local.cleaned_prefix_slash,
        "${local.cleaned_prefix_slash}*"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "data" {
  bucket = aws_s3_bucket.data.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

############################
# Useful outputs
############################

output "bucket_name" {
  value = aws_s3_bucket.data.bucket
}

output "etl_policy_arn" {
  value = aws_iam_policy.etl_access.arn
}

output "predictions_policy_arn" {
  value = aws_iam_policy.predictions_access.arn
}
