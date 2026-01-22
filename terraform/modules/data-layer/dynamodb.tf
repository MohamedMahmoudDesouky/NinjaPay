# Sessions Table
resource "aws_dynamodb_table" "sessions" {
  name           = "fintech-sessions"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "userId"
  range_key      = "sessionId"

  attribute {
    name = "userId"
    type = "S"
  }
  attribute {
    name = "sessionId"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.data_encryption.arn
  }

  tags = var.tags
}

# Auto Scaling for Sessions Table
resource "aws_appautoscaling_target" "dynamodb_sessions_read" {
  service_namespace  = "dynamodb"
  resource_id        = "table/${aws_dynamodb_table.sessions.name}"
  scalable_dimension  = "dynamodb:table:ReadCapacityUnits"
  min_capacity       = 5
  max_capacity       = 100
}

resource "aws_appautoscaling_policy" "dynamodb_sessions_read" {
  name               = "read-scaling-policy"
  service_namespace  = "dynamodb"
  resource_id        = aws_appautoscaling_target.dynamodb_sessions_read.resource_id
  scalable_dimension  = aws_appautoscaling_target.dynamodb_sessions_read.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_target" "dynamodb_sessions_write" {
  service_namespace  = "dynamodb"
  resource_id        = "table/${aws_dynamodb_table.sessions.name}"
  scalable_dimension  = "dynamodb:table:WriteCapacityUnits"
  min_capacity       = 5
  max_capacity       = 100
}

resource "aws_appautoscaling_policy" "dynamodb_sessions_write" {
  name               = "write-scaling-policy"
  service_namespace  = "dynamodb"
  resource_id        = aws_appautoscaling_target.dynamodb_sessions_write.resource_id
  scalable_dimension  = aws_appautoscaling_target.dynamodb_sessions_write.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

# Add other tables (transactions, accounts) similarly...