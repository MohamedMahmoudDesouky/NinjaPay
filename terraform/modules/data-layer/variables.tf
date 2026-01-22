variable "project_name" {
  type    = string
  default = "ninjapay"
}

variable "vpc_id" {
  type = string
}

variable "db_subnets" {
  type = list(string)
}

variable "ecs_sg_id" {
  type = string
}

variable "eks_fargate_pod_role_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

# For S3 bucket naming
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}