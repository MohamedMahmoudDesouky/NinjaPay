resource "aws_budgets_budget" "monthly_total" {
  name              = "${var.project_name}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

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


# Per-Service Budgets
locals {
  service_budgets = {
    "Amazon Elastic Container Service for Kubernetes" = 2000
    "Amazon Relational Database Service"            = 1500
    "Amazon ElastiCache"                            = 500
    "Amazon DynamoDB"                               = 300
    "Amazon Simple Storage Service"                 = 200
  }
}

resource "aws_budgets_budget" "service" {
  for_each = local.service_budgets

  name              = "${var.project_name}-${replace(each.key, "/ /", "-")}-budget"
  budget_type       = "COST"
  limit_amount      = each.value
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  cost_filter {
    name   = "Service"
    values = [each.key]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}