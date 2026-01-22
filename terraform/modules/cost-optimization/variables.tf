variable "project_name" {
  type    = string
  default = "ninjapay"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "account_id" {
  type = string
}

variable "alert_email" {
  type    = string
  default = "team-platform@yourcompany.com"
}

variable "monthly_budget_limit" {
  type    = string
  default = "5000"
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}