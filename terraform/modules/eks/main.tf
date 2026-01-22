# EKS Cluster
resource "aws_eks_cluster" "prod" {
  name     = "${var.project_name}-cluster"
  version  = "1.30" # Use latest stable
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnets, var.public_subnets)
    endpoint_private_access = true
    endpoint_public_access  = true # Set to false in prod
    public_access_cidrs     = ["0.0.0.0/0"] # Restrict later
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-cluster" }
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_amazon_eks_cluster_policy,
    aws_iam_role_policy_attachment.cluster_amazon_eks_vpc_resource_controller
  ]
}

# EKS Node Group (Fargate + Managed Nodes)
resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.prod.name
  fargate_profile_name   = "default"
  pod_execution_role_arn = aws_iam_role.fargate_pod.arn
  subnet_ids             = var.private_subnets

  selector {
    namespace = "default"
  }
  selector {
    namespace = "kube-system"
  }
  selector {
    namespace = "fintech-prod"
  }

  depends_on = [aws_eks_cluster.prod]
}

# Optional: Managed Node Group (for DaemonSets like CNI, monitoring)
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.prod.name
  node_group_name = "system-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnets
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "system"
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-system-ng" }
  )

  depends_on = [
    aws_eks_cluster.prod,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly
  ]
}