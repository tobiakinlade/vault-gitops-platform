variable "key_name" {
  description = "Name of the KMS key"
  type        = string
}

variable "key_description" {
  description = "Description of the KMS key"
  type        = string
  default     = "KMS key for HashiCorp Vault auto-unseal"
}

variable "deletion_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction"
  type        = number
  default     = 10
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

variable "vault_namespace" {
  description = "Kubernetes namespace where Vault is deployed"
  type        = string
  default     = "vault"
}

variable "vault_service_account" {
  description = "Kubernetes service account used by Vault"
  type        = string
  default     = "vault"
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA"
  type        = string
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
