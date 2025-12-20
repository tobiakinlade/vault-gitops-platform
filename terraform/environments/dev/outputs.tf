output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "kms_key_id" {
  description = "KMS key ID for Vault auto-unseal"
  value       = module.kms.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for Vault auto-unseal"
  value       = module.kms.kms_key_arn
}

output "vault_kms_role_arn" {
  description = "IAM role ARN for Vault KMS access"
  value       = module.kms.vault_kms_role_arn
}

output "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  value       = module.vault.vault_namespace
}

output "vault_service_account" {
  description = "Vault service account name"
  value       = module.vault.vault_service_account_name
}

output "vault_release_status" {
  description = "Vault Helm release status"
  value       = module.vault.vault_release_status
}

# Helpful commands
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_id} --region ${var.aws_region}"
}

output "vault_ui_access" {
  description = "Command to access Vault UI"
  value       = "kubectl get svc -n ${module.vault.vault_namespace} ${module.vault.vault_ui_service_name}"
}

output "vault_port_forward" {
  description = "Command to port-forward to Vault"
  value       = "kubectl port-forward -n ${module.vault.vault_namespace} svc/${module.vault.vault_service_name} 8200:8200"
}


