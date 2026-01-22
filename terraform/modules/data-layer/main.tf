# Generate unique suffix to avoid AWS Secrets Manager deletion lock
resource "random_string" "secret_suffix" {
  length  = 6
  special = false
  upper   = false
}