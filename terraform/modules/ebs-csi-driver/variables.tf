# terraform/modules/ebs-csi-driver/variables.tf

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "addon_version" {
  description = "Version of the EBS CSI driver addon. Leave blank for latest."
  type        = string
  default     = null
}

variable "set_as_default" {
  description = "Set gp3 as the default StorageClass"
  type        = bool
  default     = true
}
