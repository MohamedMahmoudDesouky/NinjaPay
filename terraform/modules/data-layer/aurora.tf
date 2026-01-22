# DB Subnet Group
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
}