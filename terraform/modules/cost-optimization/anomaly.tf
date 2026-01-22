# SNS Topic for Cost Alerts
resource "aws_sns_topic" "cost_alerts" {
  name = "${var.project_name}-cost-alerts"
  tags = var.tags
}

# Email subscription
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}




resource "aws_ce_anomaly_monitor" "main" {
  name         = "${var.project_name}-anomaly-monitor"
  monitor_type = "DIMENSIONAL"

  monitor_dimension = "LINKED_ACCOUNT"
}





# Anomaly Subscription - CORRECT v5.0+ syntax
resource "aws_ce_anomaly_subscription" "alerts" {
  name       = "${var.project_name}-anomaly-subscription"
  account_id = var.account_id
  frequency  = "IMMEDIATE"

  monitor_arn_list = [
    aws_ce_anomaly_monitor.main.id
  ]

  threshold_expression {
    dimension {
      key    = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values = ["20"]
    }
  }

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_alerts.arn
  }
}
