resource "aws_wellarchitected_workload" "fintech_prod" {
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