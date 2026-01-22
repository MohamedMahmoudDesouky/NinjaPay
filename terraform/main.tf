
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

