variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev-lite"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "vault-demo"
}

# VPC Configuration - Smaller CIDR for learning
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/20"  # Smaller than standard /16
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets - Only 2 AZs for cost savings"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets - Only 2 AZs for cost savings"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway to save costs"
  type        = bool
  default     = true
}

# EKS Configuration - Minimal for learning
variable "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "node_instance_types" {
  description = "Instance types for EKS nodes - t3.small for learning"
  type        = list(string)
  default     = ["t3.small"]  
}

variable "node_desired_size" {
  description = "Desired number of worker nodes - Reduced for learning"
  type        = number
  default     = 2  # Instead of 3
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1  # Can scale to 1 when not in use
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_disk_size" {
  description = "Disk size for worker nodes in GB"
  type        = number
  default     = 15  # Reduced from 20GB
}

# Vault Configuration - Minimal HA for learning
variable "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "vault_replicas" {
  description = "Number of Vault server replicas - Reduced for learning"
  type        = number
  default     = 1  # Single node instead of 3 for learning
}

variable "vault_storage_size" {
  description = "Storage size for Vault data"
  type        = string
  default     = "5Gi"  # Reduced from 10Gi
}
