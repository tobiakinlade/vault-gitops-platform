# terraform/modules/ecr/variables.tf

variable "project_name" {
  description = "Project name for ECR repositories"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "force_delete_image" {
  description = "Force delete images when destroying repository (true for dev, false for prod)"
  type        = bool
  default     = true
}

variable "scan_on_push" {
  description = "Scan images for vulnerabilities on push"
  type        = bool
  default     = true
}

variable "image_retention_count" {
  description = "Number of images to retain (older images deleted automatically)"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}
