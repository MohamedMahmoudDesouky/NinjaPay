# Reuse existing KMS key or create new one
resource "aws_kms_key" "data_encryption" {
  description             = "FinTech data encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = var.tags
}

resource "aws_kms_alias" "data_encryption" {
  name          = "alias/fintech-data-key"
  target_key_id = aws_kms_key.data_encryption.key_id
}