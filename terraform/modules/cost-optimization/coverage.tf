resource "aws_cloudwatch_dashboard" "cost_coverage" {
  dashboard_name = "${var.project_name}-coverage"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Usage", "EstimatedCharges", "Currency", "USD"]
          ]
          region  = "us-east-1"
          title   = "Estimated Charges"
          view    = "timeSeries"
          stacked = false
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWSBudgets", "ActualSpend", "BudgetName", "Monthly-Cost-Budget"]
          ]
          region  = "us-east-1"
          title   = "Budget vs Actual"
          view    = "timeSeries"
        }
      }
    ]
  })
}