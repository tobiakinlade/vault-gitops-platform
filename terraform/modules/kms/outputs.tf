output "kms_key_id" {
  description = "The globally unique identifier for the KMS key"
  value       = aws_kms_key.vault.id
}

output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key"
  value       = aws_kms_key.vault.arn
}

output "kms_key_alias" {
  description = "The alias of the KMS key"
  value       = aws_kms_alias.vault.name
}

output "vault_kms_role_arn" {
  description = "IAM role ARN for Vault to assume (IRSA)"
  value       = aws_iam_role.vault_kms.arn
}

output "vault_kms_role_name" {
  description = "IAM role name for Vault"
  value       = aws_iam_role.vault_kms.name
}

output "vault_kms_policy_arn" {
  description = "IAM policy ARN for KMS access"
  value       = aws_iam_policy.vault_kms.arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for KMS audit logs"
  value       = aws_cloudwatch_log_group.kms_audit.name
}
