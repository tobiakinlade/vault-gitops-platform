variable "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "vault_release_name" {
  description = "Helm release name for Vault"
  type        = string
  default     = "vault"
}

variable "vault_chart_version" {
  description = "Version of the Vault Helm chart"
  type        = string
  default     = "0.27.0"
}

variable "vault_replicas" {
  description = "Number of Vault server replicas for HA"
  type        = number
  default     = 3
}

variable "vault_storage_size" {
  description = "Size of persistent volume for Vault (Raft storage)"
  type        = string
  default     = "10Gi"
}

variable "vault_storage_class" {
  description = "Storage class for Vault persistent volumes"
  type        = string
  default     = "gp3"
}

variable "kms_key_id" {
  description = "KMS key ID for Vault auto-unseal"
  type        = string
}

variable "vault_kms_role_arn" {
  description = "IAM role ARN for Vault to access KMS"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "enable_ui" {
  description = "Enable Vault UI"
  type        = bool
  default     = true
}

variable "enable_audit_logs" {
  description = "Enable audit logging to CloudWatch"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group" {
  description = "CloudWatch log group for Vault audit logs"
  type        = string
  default     = "/aws/vault/audit"
}

variable "injector_enabled" {
  description = "Enable Vault Agent Injector"
  type        = bool
  default     = true
}

variable "metrics_enabled" {
  description = "Enable Prometheus metrics"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "storage_class" {
  description = "StorageClass to use for Vault persistent volumes"
  type        = string
  default     = "gp3"
}
