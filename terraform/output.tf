# outputs.tf
output "organization_root_id" {
  value = aws_organizations_organization.org.roots[0].id
}

output "management_account_id" {
  value = aws_organizations_organization.org.master_account_id
}

# output "terraform_state_bucket" {
#   value = aws_s3_bucket.terraform_state.bucket
# }


