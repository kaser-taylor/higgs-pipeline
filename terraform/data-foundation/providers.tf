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
  profile = var.aws_profile
}