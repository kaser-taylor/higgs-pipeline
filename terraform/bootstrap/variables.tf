# Variables

variable "region" {
  type    = string
  default = "us-west-2"
}

variable "env" {
  type    = string
  default = "bootstrap"
}

variable "alert_email" {
  type = string
}

variable "monthly_limit_usd" {
  type    = string
  default = "5"
}

variable "aws_profile" {
  type = string
}