resource "aws_dynamodb_table" "tf_lock" {
  name         = "higgs-${var.env}-dynamostatelock-${data.aws_caller_identity.me.account_id}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }
}