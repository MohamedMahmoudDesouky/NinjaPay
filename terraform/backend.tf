# # backend.tf — now switch to remote S3 backend
# terraform {
#   backend "s3" {
#     bucket         = "ninjapay-terraform-state-bucket387"
#     key            = "terraform.tfstate"
#     region         = "us-east-1"
#     # dynamodb_table = "ninjapay-terraform-lock"
#     encrypt        = true
#   }
# }