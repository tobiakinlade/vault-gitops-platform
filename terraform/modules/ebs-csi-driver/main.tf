# terraform/modules/ebs-csi-driver/main.tf
# EBS CSI Driver Module for AWS EKS
# Provides persistent volume support for StatefulSets like Vault

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get EKS cluster details
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# Get OIDC provider for IRSA (IAM Roles for Service Accounts)
data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# IAM role for EBS CSI driver with IRSA
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.cluster.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(data.aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Attach AWS managed policy for EBS CSI driver
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Install EBS CSI driver as an EKS addon
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.addon_version
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  # Resolve conflicts by overwriting
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_driver
  ]
}

# Create gp3 StorageClass (better performance and cost than gp2)
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = var.set_as_default ? "true" : "false"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [
    aws_eks_addon.ebs_csi_driver
  ]
}

# Optional: Remove default annotation from gp2 if setting gp3 as default
resource "null_resource" "remove_gp2_default" {
  count = var.set_as_default ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=false --overwrite || true
    EOT
  }

  depends_on = [
    kubernetes_storage_class_v1.gp3
  ]
}
