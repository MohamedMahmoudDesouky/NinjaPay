# API Keys Secret
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
}