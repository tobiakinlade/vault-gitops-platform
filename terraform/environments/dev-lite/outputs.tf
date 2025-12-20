output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "kms_key_arn" {
  description = "KMS key ARN for Vault auto-unseal"
  value       = module.kms.kms_key_arn
}

output "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  value       = module.vault.vault_namespace
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ${var.aws_region}"
}




