output "cluster_endpoint" {
  value = aws_eks_cluster.prod.endpoint
}

output "cluster_security_group_id" {
  value = aws_eks_cluster.prod.vpc_config[0].cluster_security_group_id
}

output "kubeconfig" {
  value = {
    apiVersion      = "v1"
    clusters = [{
      cluster = {
        server = aws_eks_cluster.prod.endpoint
        certificate-authority-data = aws_eks_cluster.prod.certificate_authority[0].data
      }
      name = "kubernetes"
    }]
    contexts = [{
      context = {
        cluster = "kubernetes"
        user    = aws_eks_cluster.prod.name
      }
      name = aws_eks_cluster.prod.name
    }]
    current-context = aws_eks_cluster.prod.name
    kind            = "Config"
    users = [{
      name = aws_eks_cluster.prod.name
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args       = ["eks", "get-token", "--cluster-name", aws_eks_cluster.prod.name]
        }
      }
    }]
  }
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.prod.name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate authority data for the EKS cluster"
  value       = aws_eks_cluster.prod.certificate_authority[0].data
}