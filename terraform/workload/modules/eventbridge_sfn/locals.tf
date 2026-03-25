locals {
  name_prefix = "${var.project}-${var.env}"

  tags = {
    Project     = var.project
    Environment = var.env
    Component   = "orchestration"
    ManagedBy   = "terraform"
  }

  # Convenience aliases pointing at the data lookups above.
  # Once the Lambda modules are co-located in this root, delete the data
  # lookups above and point these at the actual aws_lambda_function resources.
  lambda_check_state   = data.aws_lambda_function.check_state
  lambda_etl           = data.aws_lambda_function.etl
  lambda_predict       = data.aws_lambda_function.predict
  lambda_load_redshift = data.aws_lambda_function.load_redshift
  lambda_mark_done     = data.aws_lambda_function.mark_done
  lambda_mark_failed   = data.aws_lambda_function.mark_failed
}