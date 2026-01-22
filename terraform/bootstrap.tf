# # backend-resources.tf

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
# }