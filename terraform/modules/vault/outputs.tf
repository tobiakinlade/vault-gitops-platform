output "vault_namespace" {
  description = "Kubernetes namespace where Vault is deployed"
  value       = kubernetes_namespace.vault.metadata[0].name
}

output "vault_service_account_name" {
  description = "Name of the Vault service account"
  value       = kubernetes_service_account.vault.metadata[0].name
}

output "vault_release_name" {
  description = "Helm release name for Vault"
  value       = helm_release.vault.name
}

output "vault_release_status" {
  description = "Status of the Vault Helm release"
  value       = helm_release.vault.status
}

output "vault_service_name" {
  description = "Name of the Vault service"
  value       = "${var.vault_release_name}-active"
}

output "vault_internal_service_name" {
  description = "Name of the Vault internal service"
  value       = "${var.vault_release_name}-internal"
}

output "vault_ui_service_name" {
  description = "Name of the Vault UI service"
  value       = "${var.vault_release_name}-ui"
}

output "cloudwatch_audit_log_group" {
  description = "CloudWatch log group for Vault audit logs"
  value       = var.enable_audit_logs ? aws_cloudwatch_log_group.vault_audit[0].name : ""
}
