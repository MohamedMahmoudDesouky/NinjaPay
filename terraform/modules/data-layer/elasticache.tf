resource "aws_elasticache_subnet_group" "redis" {
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
}