# # backend.tf — now switch to remote S3 backend
# terraform {
#   backend "s3" {
#     bucket         = "ninjapay-terraform-state-bucket387"
#     key            = "terraform.tfstate"
#     region         = "us-east-1"
#     # dynamodb_table = "ninjapay-terraform-lock"
#     encrypt        = true
#   }
# }# # backend-resources.tf

# # Reclaim management of the S3 state bucket
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "ninjapay-terraform-state-bucket387"

#   versioning {
#     enabled = true
#   }

#   # lifecycle {
#   #   prevent_destroy = true  # Prevent org deletion!
#   # }

#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }

#   tags = {
#     Name = "Terraform State Bucket"
#   }
# }

# resource "aws_s3_bucket_public_access_block" "terraform_state" {
#   bucket                  = aws_s3_bucket.terraform_state.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# # Manage the DynamoDB lock table
# resource "aws_dynamodb_table" "terraform_lock" {
#   name         = "ninjapay-terraform-lock"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }resource "aws_budgets_budget" "monthly_cost" {
  name              = "Monthly-Cost-Budget"
  budget_type       = "COST"
  limit_amount      = var.budget_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["finance@yourcompany.com"]
  }
  # ← No cost_filter = applies to entire org
}
module "vpc" {
  source       = "./modules/vpc"
  project_name = "ninjapay"
  vpc_cidr     = "10.0.0.0/16"
  region       = "us-east-1"

  tags = {
    Environment = "Production"
    Project     = "FinTechGlobal"
    Owner       = "team-platform@yourcompany.com"
  }
}

# After VPC module
module "eks" {
  source = "./modules/eks"

  project_name    = "ninjapay"
  region          = "us-east-1"
  account_id      = "797923187401" # Your account ID
  private_subnets = module.vpc.private_app_subnets
  public_subnets  = module.vpc.public_subnets

  tags = {
    Environment = "Production"
    Project     = "FinTechGlobal"
    Owner       = "team-platform@yourcompany.com"
  }
}



# AFTER EKS module is declared
module "k8s_workloads" {
  source = "./modules/k8s-workloads"

  cluster_endpoint                   = module.eks.cluster_endpoint
  cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
  cluster_name                       = module.eks.cluster_name
}

module "cost_optimization" {
  source = "./modules/cost-optimization"

  project_name           = "ninjapay"
  region                 = "us-east-1"
  account_id             = "797923187401"
  alert_email            = "team-platform@yourcompany.com"
  monthly_budget_limit   = "5000"

  tags = {
    Environment = "Production"
    Project     = "FinTechGlobal"
    Owner       = "team-platform@yourcompany.com"
  }
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

module "data_layer" {
  source = "./modules/data-layer"

  project_name              = "ninjapay"
  vpc_id                    = module.vpc.vpc_id
  db_subnets                = module.vpc.private_db_subnets
  ecs_sg_id                 = module.eks.cluster_security_group_id # Or create dedicated SG
  eks_fargate_pod_role_name = "${var.project_name}-eks-fargate-pod-role"

  tags = {
    Environment = "Production"
    Project     = "FinTechGlobal"
    Owner       = "team-platform@yourcompany.com"
  }
}
# Create AWS Organization
resource "aws_organizations_organization" "org" {
  feature_set = "ALL" # Enables all features (policies, etc.)


  # Explicitly enable policy types
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]




}

# Use a data source instead
# data "aws_organizations_organization" "existing" {}

# Locals for reuse
locals {
  root_id = aws_organizations_organization.org.roots[0].id
}



# === OUs ===
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = local.root_id
      lifecycle {
      prevent_destroy = true
    }
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = local.root_id
      lifecycle {
      prevent_destroy = true
    }
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = local.root_id
      lifecycle {
      prevent_destroy = true
    }
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = local.root_id
      lifecycle {
      prevent_destroy = true
    }
}

# Sub-OUs under Workloads
resource "aws_organizations_organizational_unit" "prod" {
  name      = "Production"
  parent_id = aws_organizations_organizational_unit.workloads.id
      lifecycle {
      prevent_destroy = true
    }
}

resource "aws_organizations_organizational_unit" "staging" {
  name      = "Staging"
  parent_id = aws_organizations_organizational_unit.workloads.id
      lifecycle {
      prevent_destroy = true
    }
}

resource "aws_organizations_organizational_unit" "development" {
  name      = "Development"
  parent_id = aws_organizations_organizational_unit.workloads.id
      lifecycle {
      prevent_destroy = true
    }
}

# === Accounts ===
resource "aws_organizations_account" "security_audit" {
  name      = "Security-Audit Account"
  email     = "security-audit@yourcompany.com"
  parent_id = aws_organizations_organizational_unit.security.id
}

# resource "aws_organizations_account" "security_logging" {
#   name      = "Security-Logging Account"
#   email     = "security-logging@yourcompany.com"
#   parent_id = aws_organizations_organizational_unit.security.id
# }

resource "aws_organizations_account" "shared_services" {
  name      = "Shared-Services Account"
  email     = "shared-services@yourcompany.com"
  parent_id = aws_organizations_organizational_unit.infrastructure.id
}

resource "aws_organizations_account" "network_hub" {
  name      = "Network-Hub Account"
  email     = "network-hub@yourcompany.com"
  parent_id = aws_organizations_organizational_unit.infrastructure.id
}

# resource "aws_organizations_account" "prod_us" {
#   name      = "Prod-US Account"
#   email     = "prod-us@yourcompany.com"
#   parent_id = aws_organizations_organizational_unit.prod.id
# }

# resource "aws_organizations_account" "prod_eu" {
#   name      = "Prod-EU Account"
#   email     = "prod-eu@yourcompany.com"
#   parent_id = aws_organizations_organizational_unit.prod.id
# }

# resource "aws_organizations_account" "staging" {
#   name      = "Staging Account"
#   email     = "staging@yourcompany.com"
#   parent_id = aws_organizations_organizational_unit.staging.id
# }

# resource "aws_organizations_account" "dev" {
#   name      = "Dev Account"
#   email     = "dev@yourcompany.com"
#   parent_id = aws_organizations_organizational_unit.development.id
# }

# resource "aws_organizations_account" "sandbox" {
#   name      = "Sandbox Account"
#   email     = "sandbox@yourcompany.com"
#   parent_id = aws_organizations_organizational_unit.sandbox.id
# }

# === SCPs ===
resource "aws_organizations_policy" "deny_root" {
  name        = "DenyRootUserAccess"
  description = "Deny all actions for root user"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/deny-root-scp.json")
}

resource "aws_organizations_policy" "region_restriction" {
  name        = "RegionRestriction"
  description = "Allow only us-east-1"
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/region-restriction-scp.json")
}

resource "aws_organizations_policy" "deny_cloudtrail_disable" {
  name        = "DenyCloudTrailDisable"
  description = "Prevent disabling CloudTrail"
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Deny"
        Action   = ["cloudtrail:StopLogging", "cloudtrail:DeleteTrail"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_organizations_policy" "tag_policy" {
  name        = "FinTechTagPolicy"
  description = "Enforce mandatory tags"
  type        = "TAG_POLICY"
  content     = file("${path.module}/policies/tag-policy.json")
}

# Attach SCPs to root
resource "aws_organizations_policy_attachment" "root_deny_root" {
  policy_id  = aws_organizations_policy.deny_root.id
  target_id  = local.root_id
  depends_on = [aws_organizations_organization.org]

}

resource "aws_organizations_policy_attachment" "root_region_restriction" {
  policy_id  = aws_organizations_policy.region_restriction.id
  target_id  = local.root_id
  depends_on = [aws_organizations_organization.org]

}

resource "aws_organizations_policy_attachment" "root_cloudtrail" {
  policy_id  = aws_organizations_policy.deny_cloudtrail_disable.id
  target_id  = local.root_id
  depends_on = [aws_organizations_organization.org]

}

resource "aws_organizations_policy_attachment" "tag_policy_root" {
  policy_id  = aws_organizations_policy.tag_policy.id
  target_id  = local.root_id
  depends_on = [aws_organizations_organization.org]
}

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
}resource "aws_cloudwatch_dashboard" "cost_coverage" {
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
}# Generate unique suffix to avoid AWS Secrets Manager deletion lock
resource "random_string" "secret_suffix" {
  length  = 6
  special = false
  upper   = false
}
# Create S3 bucket for CUR
resource "aws_s3_bucket" "cur" {
  bucket = "${var.project_name}-cost-and-usage-report-${random_string.suffix.result}"
  tags   = var.tags
}


# Allow AWS CUR service to write to bucket
resource "aws_s3_bucket_policy" "cur" {
  bucket = aws_s3_bucket.cur.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowAWSBillingToWrite"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cur.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceArn" = "arn:aws:cur:${var.region}:${var.account_id}:report/${var.project_name}-cur"
            "aws:SourceAccount" = var.account_id
          }
        }
      },
      {
        Sid       = "AllowAWSBillingToReadBucketPolicy"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetBucketAcl", "s3:GetBucketPolicy"]
        Resource  = aws_s3_bucket.cur.arn
        Condition = {
          StringEquals = {
            "aws:SourceArn" = "arn:aws:cur:${var.region}:${var.account_id}:report/${var.project_name}-cur"
            "aws:SourceAccount" = var.account_id
          }
        }
      }
    ]
  })
}





resource "aws_s3_bucket_public_access_block" "cur" {
  bucket                  = aws_s3_bucket.cur.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# # Enable Cost & Usage Report
# resource "aws_cur_report_definition" "main" {
#   report_name               = "${var.project_name}-cur"  # ← CHANGED FROM 'name' TO 'report_name'
#   additional_schema_elements = ["RESOURCES"]
#   compression               = "GZIP"
#   format                    = "textORcsv"
#   report_versioning         = "CREATE_NEW_REPORT"
#   s3_bucket                 = aws_s3_bucket.cur.id
#   s3_prefix                 = "cur"
#   s3_region                 = var.region
#   time_unit                 = "HOURLY"

#   depends_on = [
#     aws_s3_bucket_public_access_block.cur,
#     aws_s3_bucket_policy.cur
#     ]

# }

# # Athena Integration
# output "cur_s3_path" {
#   value       = "s3://${aws_s3_bucket.cur.bucket}/cur/"
#   description = "Path to CUR data for Athena integration"
# }variable "project_name" {
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
}# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-aurora-subnets"
  subnet_ids = var.db_subnets

  tags = var.tags
}

# Security Group
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-aurora-sg"
  description = "Allow ECS to access Aurora"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_sg_id] # From EKS module
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Enhanced Monitoring Role
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
  role       = aws_iam_role.rds_monitoring.name
}

# Generate random password (securely)
resource "random_password" "db_master" {
  length  = 32
  special = true
}

# Store in Secrets Manager
resource "aws_secretsmanager_secret" "aurora" {
  name                    = "fintech/db-credentials-${random_string.secret_suffix.result}"
  description             = "Aurora PostgreSQL credentials"
  kms_key_id = aws_kms_key.data_encryption.arn      # ✅ Correct
}

resource "aws_secretsmanager_secret_version" "aurora" {
  secret_id = aws_secretsmanager_secret.aurora.id
  secret_string = jsonencode({
    username = "fintechadmin"
    password = random_password.db_master.result
    engine   = "postgres"
    port     = 5432
    dbname   = "fintech"
    host     = aws_rds_cluster.aurora.endpoint
  })
}

# Aurora Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier              = "${var.project_name}-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = "15.15"
  master_username                 = "fintechadmin"
  master_password                 = random_password.db_master.result
  database_name                   = "fintech"
  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  storage_encrypted               = true
  kms_key_id                      = aws_kms_key.data_encryption.arn
  enabled_cloudwatch_logs_exports = ["postgresql"]
  deletion_protection             = false
  enable_http_endpoint            = true
  skip_final_snapshot = true    # ← ADD THIS
  tags = var.tags
}

# Writer Instance
resource "aws_rds_cluster_instance" "writer" {
  identifier              = "${var.project_name}-aurora-writer"
  cluster_identifier      = aws_rds_cluster.aurora.id
  instance_class          = "db.r6g.large"
  engine                  = aws_rds_cluster.aurora.engine
  performance_insights_enabled = true
  monitoring_interval     = 60
  monitoring_role_arn     = aws_iam_role.rds_monitoring.arn
  publicly_accessible     = false

  tags = var.tags
}

# Reader Instance
resource "aws_rds_cluster_instance" "reader" {
  identifier              = "${var.project_name}-aurora-reader"
  cluster_identifier      = aws_rds_cluster.aurora.id
  instance_class          = "db.r6g.large"
  engine                  = aws_rds_cluster.aurora.engine
  performance_insights_enabled = true
  publicly_accessible     = false

  tags = var.tags
}

# Aurora Auto Scaling (Read Replicas)
resource "aws_appautoscaling_target" "aurora_replicas" {
  service_namespace  = "rds"
  resource_id        = "cluster:${aws_rds_cluster.aurora.cluster_identifier}"
  scalable_dimension  = "rds:cluster:ReadReplicaCount"
  min_capacity       = 1
  max_capacity       = 5
}

resource "aws_appautoscaling_policy" "aurora_replicas" {
  name               = "aurora-replica-scaling"
  service_namespace  = "rds"
  resource_id        = aws_appautoscaling_target.aurora_replicas.resource_id
  scalable_dimension  = aws_appautoscaling_target.aurora_replicas.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "RDSReaderAverageCPUUtilization"
    }
    target_value       = 70
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}# Sessions Table
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

# Add other tables (transactions, accounts) similarly...resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnets"
  subnet_ids = var.db_subnets

  tags = var.tags
}

resource "aws_security_group" "elasticache" {
  name        = "${var.project_name}-elasticache-sg"
  description = "Allow ECS to access Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.ecs_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "random_password" "redis_auth" {
  length  = 32
  special = true
# ONLY allow safe special chars for Redis AUTH
  override_special = "!#$%^&*()_+-=[]{}|"
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name       = "fintech/redis-auth-${random_string.secret_suffix.result}"
  kms_key_id = aws_kms_key.data_encryption.key_id
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.redis_auth.result
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = "${var.project_name}-redis-cluster"
  description                   = "FinTech Redis cluster"
  engine                        = "redis"
  engine_version                = "7.0"
  node_type                     = "cache.r6g.large"
  num_cache_clusters            = 2
  subnet_group_name             = aws_elasticache_subnet_group.redis.name
  security_group_ids            = [aws_security_group.elasticache.id]
  at_rest_encryption_enabled    = true
  transit_encryption_enabled    = true
  auth_token                    = random_password.redis_auth.result
  automatic_failover_enabled    = true
  multi_az_enabled              = true
  snapshot_retention_limit      = 7

  tags = var.tags
}# Reuse existing KMS key or create new one
resource "aws_kms_key" "data_encryption" {
  description             = "FinTech data encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = var.tags
}

resource "aws_kms_alias" "data_encryption" {
  name          = "alias/fintech-data-key"
  target_key_id = aws_kms_key.data_encryption.key_id
}# Generate unique suffix to avoid AWS Secrets Manager deletion lock
resource "random_string" "secret_suffix" {
  length  = 6
  special = false
  upper   = false
}# Log bucket for access logging
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-s3-logs-${random_string.suffix.result}"

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Main data lake bucket
resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.project_name}-data-lake-${random_string.suffix.result}"

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket                  = aws_s3_bucket.data_lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.data_encryption.key_id
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}

# Folder structure (prefixes)
resource "aws_s3_object" "folders" {
  for_each = toset([
    "raw/transactions/",
    "raw/logs/",
    "raw/events/",
    "processed/daily-reports/",
    "processed/aggregations/",
    "archive/compliance/",
    "analytics/ml-data/"
  ])

  bucket = aws_s3_bucket.data_lake.id
  key    = each.value
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    id     = "ArchiveOldData"
    status = "Enabled"

    filter {
      prefix = "archive/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 180
      storage_class = "GLACIER"
    }
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
  }

  rule {
    id     = "DeleteOldVersions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  name   = "EntireBucket"

  # Apply to entire bucket
  filter {
    prefix = ""  
  }

  # Move to ARCHIVE_ACCESS after 90 days of no access
  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }

  # Move to DEEP_ARCHIVE_ACCESS after 180 days of no access
  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}# API Keys Secret
resource "aws_secretsmanager_secret" "api_keys" {
  name = "fintech/api-keys-${random_string.secret_suffix.result}"
kms_key_id = aws_kms_key.data_encryption.key_id
}

resource "aws_secretsmanager_secret_version" "api_keys" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    stripe_api_key   = "sk_live_xxxxx"
    sendgrid_api_key = "SG.xxxxx"
  })
}

# Encryption Key (Binary)
resource "aws_secretsmanager_secret" "encryption_key" {
  name       = "fintech/encryption-key-${random_string.secret_suffix.result}"
  kms_key_id = aws_kms_key.data_encryption.key_id
}

resource "aws_secretsmanager_secret_version" "encryption_key" {
  secret_id     = aws_secretsmanager_secret.encryption_key.id
  secret_binary = base64encode(random_password.encryption_key.result)
}

resource "random_password" "encryption_key" {
  length  = 32
  special = false
}

# Grant EKS Pod Execution Role Access to Secrets
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-secrets-access"
  description = "Allow access to FinTech secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.aurora.arn,
          aws_secretsmanager_secret.redis_auth.arn,
          aws_secretsmanager_secret.api_keys.arn,
          aws_secretsmanager_secret.encryption_key.arn
        ]
      }
    ]
  })
}

# Attach to EKS Fargate Pod Role (from EKS module)
resource "aws_iam_role_policy_attachment" "secrets_access" {
  policy_arn = aws_iam_policy.secrets_access.arn
  role       = var.eks_fargate_pod_role_name
}variable "project_name" {
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
}# Cluster Role
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_amazon_eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_amazon_eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# Fargate Pod Execution Role
resource "aws_iam_role" "fargate_pod" {
  name = "${var.project_name}-eks-fargate-pod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fargate_pod_secrets" {
  policy_arn = aws_iam_policy.secrets_manager.arn
  role       = aws_iam_role.fargate_pod.name
}

# Node Role (for managed nodes)
resource "aws_iam_role" "node" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# Custom Policy: Secrets Manager Access
resource "aws_iam_policy" "secrets_manager" {
  name        = "${var.project_name}-secrets-manager-policy"
  description = "Allow access to FinTech secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:fintech/*"
        ]
      }
    ]
  })
}# EKS Cluster
resource "aws_eks_cluster" "prod" {
  name     = "${var.project_name}-cluster"
  version  = "1.30" # Use latest stable
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnets, var.public_subnets)
    endpoint_private_access = true
    endpoint_public_access  = true # Set to false in prod
    public_access_cidrs     = ["0.0.0.0/0"] # Restrict later
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-cluster" }
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_amazon_eks_cluster_policy,
    aws_iam_role_policy_attachment.cluster_amazon_eks_vpc_resource_controller
  ]
}

# EKS Node Group (Fargate + Managed Nodes)
resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.prod.name
  fargate_profile_name   = "default"
  pod_execution_role_arn = aws_iam_role.fargate_pod.arn
  subnet_ids             = var.private_subnets

  selector {
    namespace = "default"
  }
  selector {
    namespace = "kube-system"
  }
  selector {
    namespace = "fintech-prod"
  }

  depends_on = [aws_eks_cluster.prod]
}

# Optional: Managed Node Group (for DaemonSets like CNI, monitoring)
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.prod.name
  node_group_name = "system-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnets
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "system"
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-system-ng" }
  )

  depends_on = [
    aws_eks_cluster.prod,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly
  ]
}output "cluster_endpoint" {
  value = aws_eks_cluster.prod.endpoint
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.prod.vpc_config[0].cluster_security_group_id
}

output "kubeconfig" {
  value = {
    apiVersion      = "v1"
    clusters = [{
      cluster = {
        server = aws_eks_cluster.prod.endpoint
        certificate-authority-data = aws_eks_cluster.prod.certificate_authority[0].data
      }
      name = "kubernetes"
    }]
    contexts = [{
      context = {
        cluster = "kubernetes"
        user    = aws_eks_cluster.prod.name
      }
      name = aws_eks_cluster.prod.name
    }]
    current-context = aws_eks_cluster.prod.name
    kind            = "Config"
    users = [{
      name = aws_eks_cluster.prod.name
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args       = ["eks", "get-token", "--cluster-name", aws_eks_cluster.prod.name]
        }
      }
    }]
  }
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.prod.name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.prod.certificate_authority[0].data
}variable "project_name" {
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

variable "private_subnets" {
  type = list(string)
}

variable "public_subnets" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}variable "cluster_endpoint" {}
variable "cluster_certificate_authority_data" {}
variable "cluster_name" {}

provider "kubernetes" {
  alias                  = "eks"
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token

}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

# Create namespace first
resource "kubernetes_namespace_v1" "fintech_prod" {
  provider = kubernetes.eks

  metadata {
    name = "fintech-prod"
    labels = {
      name = "fintech-prod"
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "fintech_api" {
  provider = kubernetes.eks  # ← Use aliased provider

  metadata {
    name      = "fintech-api-hpa"
    namespace = kubernetes_namespace_v1.fintech_prod.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "fintech-api"
    }
    min_replicas = 3
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type               = "Utilization"
          average_utilization = 70
        }
      }
    }
    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type               = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}# VPC Module - Production Network
resource "aws_vpc" "prod" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-prod-vpc" }
  )
}

# Get AZs dynamically
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# Public Subnets (for NAT GW, ALB)
resource "aws_subnet" "public" {
  for_each = {
    for idx, az in local.azs : idx => {
      az     = az
      cidr   = cidrsubnet(var.vpc_cidr, 8, idx + 1)
      suffix = ["a", "b"][idx]
    }
  }

  vpc_id            = aws_vpc.prod.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-public-az-${each.value.suffix}"
      Tier = "public"
    }
  )
}

# Private App Subnets (for ECS)
resource "aws_subnet" "private_app" {
  for_each = {
    for idx, az in local.azs : idx => {
      az     = az
      cidr   = cidrsubnet(var.vpc_cidr, 8, idx + 11)
      suffix = ["a", "b"][idx]
    }
  }

  vpc_id            = aws_vpc.prod.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-app-az-${each.value.suffix}"
      Tier = "private-app"
    }
  )
}

# Database Subnets (for RDS/Aurora)
resource "aws_subnet" "private_db" {
  for_each = {
    for idx, az in local.azs : idx => {
      az     = az
      cidr   = cidrsubnet(var.vpc_cidr, 8, idx + 21)
      suffix = ["a", "b"][idx]
    }
  }

  vpc_id            = aws_vpc.prod.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-private-db-az-${each.value.suffix}"
      Tier = "private-db"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod.id

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-igw" }
  )
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-public-rt" }
  )
}

# Associate public subnets
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateways (one per AZ for HA)
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-nat-eip-${each.key}" }
  )
}

resource "aws_nat_gateway" "nat" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id
  depends_on    = [aws_internet_gateway.igw]

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-nat-gw-${each.key}" }
  )
}

# Private Route Table (for app & DB subnets)
resource "aws_route_table" "private" {
  for_each = aws_subnet.public

  vpc_id = aws_vpc.prod.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-private-rt-az-${["a", "b"][each.key]}" }
  )
}

# Associate private app subnets to corresponding NAT
resource "aws_route_table_association" "private_app" {
  for_each = aws_subnet.private_app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# Associate database subnets to corresponding NAT
resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# VPC Endpoints
# Gateway Endpoints (S3, DynamoDB)
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.prod.id
  service_name    = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [for rt in aws_route_table.private : rt.id]
  tags = merge(var.tags, { Name = "${var.project_name}-s3-vpce" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id          = aws_vpc.prod.id
  service_name    = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [for rt in aws_route_table.private : rt.id]
  tags = merge(var.tags, { Name = "${var.project_name}-dynamodb-vpce" })
}

# Interface Endpoints (SSM, ECR, Secrets Manager)
resource "aws_security_group" "vpce" {
  name        = "${var.project_name}-vpce-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.prod.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

locals {
  interface_services = [
    "ecr.api",
    "ecr.dkr",
    "secretsmanager",
    "ssm",
    "ssmmessages"
  ]
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_services)

  vpc_id             = aws_vpc.prod.id
  service_name       = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [for s in aws_subnet.private_app : s.id]
  security_group_ids = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-${each.value}-vpce" }
  )
}output "vpc_id" {
  value = aws_vpc.prod.id
}

output "public_subnets" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_app_subnets" {
  value = [for s in aws_subnet.private_app : s.id]
}

output "private_db_subnets" {
  value = [for s in aws_subnet.private_db : s.id]
}

output "vpc_cidr" {
  value = aws_vpc.prod.cidr_block
}variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "ninjapay"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}# outputs.tf
output "organization_root_id" {
  value = aws_organizations_organization.org.roots[0].id
}

output "management_account_id" {
  value = aws_organizations_organization.org.master_account_id
}

# output "terraform_state_bucket" {
#   value = aws_s3_bucket.terraform_state.bucket
# }


{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyRootUser",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:PrincipalArn": "arn:aws:iam::*:root"
        }
      }
    }
  ]
}{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "organizations:*",
        "servicequotas:ListRequestedServiceQuotas",
        "servicequotas:RequestServiceQuotaIncrease"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "arn:aws:iam::*:role/aws-service-role/organizations.amazonaws.com/AWSServiceRoleForOrganizations",
      "Condition": {
        "StringLike": {
          "iam:AWSServiceName": "organizations.amazonaws.com"
        }
      }
    }
  ]
}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyNonApprovedRegions",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "support:*",
        "sts:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1"]
        }
      }
    }
  ]
}{
  "tags": {
    "Environment": {
      "tag_key": { "@@assign": "Environment" },
      "tag_value": { "@@assign": ["Production", "Staging", "Development", "Sandbox"] }
    },
    "Owner": {
      "tag_key": { "@@assign": "Owner" }
    }
  }
}# provider.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.28.0"
    }
  }
}
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

{"Modules":[{"Key":"","Source":"","Dir":"."},{"Key":"cost_optimization","Source":"./modules/cost-optimization","Dir":"modules/cost-optimization"},{"Key":"data_layer","Source":"./modules/data-layer","Dir":"modules/data-layer"},{"Key":"eks","Source":"./modules/eks","Dir":"modules/eks"},{"Key":"k8s_workloads","Source":"./modules/k8s-workloads","Dir":"modules/k8s-workloads"},{"Key":"vpc","Source":"./modules/vpc","Dir":"modules/vpc"}]}# variables.tf
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

}resource "aws_wellarchitected_workload" "fintech_prod" {
  workload_name    = "FinTechGlobal-Production"
  description      = "Production workload for FinTechGlobal platform"
  environment      = "PRODUCTION"
  aws_regions      = ["us-east-1"]
  review_owner     = "team-platform@yourcompany.com"
  lenses           = ["wellarchitected", "serverless", "saas"]

  # Optional: link to actual resources (ARNs)
  # workload_share_notes = "Managed via Terraform"

  tags = {
    Environment        = "Production"
    Project            = "FinTechGlobal"
    CostCenter         = "CC-12345"
    Owner              = "team-platform@yourcompany.com"
    DataClassification = "Confidential"
  }
}

# After creation, manually:
# 1. Go to AWS Console → Well-Architected Tool
# 2. Open this workload
# 3. Answer questions for all 6 pillars
# 4. Create a baseline milestone
# 5. Address High-Risk Issues (HRIs)