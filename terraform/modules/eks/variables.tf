variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (for public load balancers)"
  type        = list(string)
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "node_group_name" {
  description = "Name of the managed node group"
  type        = string
  default     = "main"
}

variable "node_instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 30
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 5
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 6
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler tags"
  type        = bool
  default     = true
}

variable "enable_encryption" {
  description = "Enable envelope encryption of Kubernetes secrets"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of KMS key for EKS secret encryption"
  type        = string
  default     = ""
}

variable "enable_cloudwatch_logs" {
  description = "Enable EKS control plane logging to CloudWatch"
  type        = bool
  default     = true
}

variable "cluster_log_retention_days" {
  description = "Retention period for EKS cluster logs"
  type        = number
  default     = 7
}

variable "cluster_enabled_log_types" {
  description = "List of control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
