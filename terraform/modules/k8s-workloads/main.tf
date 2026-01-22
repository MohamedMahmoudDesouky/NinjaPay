variable "cluster_endpoint" {}
variable "cluster_certificate_authority_data" {}
variable "cluster_name" {}

provider "kubernetes" {
  alias                  = "eks"
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token

}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

# Create namespace first
resource "kubernetes_namespace_v1" "fintech_prod" {
  provider = kubernetes.eks

  metadata {
    name = "fintech-prod"
    labels = {
      name = "fintech-prod"
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "fintech_api" {
  provider = kubernetes.eks  # ← Use aliased provider

  metadata {
    name      = "fintech-api-hpa"
    namespace = kubernetes_namespace_v1.fintech_prod.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "fintech-api"
    }
    min_replicas = 3
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type               = "Utilization"
          average_utilization = 70
        }
      }
    }
    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type               = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}