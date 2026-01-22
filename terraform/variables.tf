# variables.tf
variable "aws_region" {
  description = "AWS region for provider"
  type        = string
  default     = "us-east-1"
}

variable "budget_limit" {
  description = "Monthly cost budget limit in USD"
  type        = string
  default     = "5000"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "ninjapay"

}