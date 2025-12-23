# Development Environment - Vault GitOps Platform

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  backend "s3" {
    bucket         = "calculator-terraform-state-dev"
    key            = "vault-platform/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "calculator-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "Tax Caculator"
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = "${var.project_name}-${var.environment}-cluster"
  
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  vpc_name             = "${var.project_name}-${var.environment}-vpc"
  cluster_name         = local.cluster_name  
  vpc_cidr             = var.vpc_cidr
  azs                  = local.azs
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  
  enable_nat_gateway   = true
  single_nat_gateway   = var.single_nat_gateway  # Cost savings for dev
  enable_flow_logs     = true
  
  environment = var.environment
  tags        = local.common_tags
}

# Add ECR module 
module "ecr" {
  source = "../../modules/ecr"

  project_name          = var.project_name
  environment           = var.environment
  force_delete_image    = true  # true for dev, false for prod
  scan_on_push          = true
  image_retention_count = 10    # Keep last 10 images

  tags = local.common_tags
}

# Update outputs to include ECR
output "ecr_backend_repository_url" {
  description = "Backend ECR repository URL"
  value       = module.ecr.backend_repository_url
}

output "ecr_frontend_repository_url" {
  description = "Frontend ECR repository URL"
  value       = module.ecr.frontend_repository_url
}

output "docker_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${module.ecr.registry_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version
  
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  
  enable_irsa             = true
  enable_encryption       = true
  enable_cloudwatch_logs  = true
  
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_disk_size      = var.node_disk_size
  
  enable_cluster_autoscaler = true
  
  environment = var.environment
  tags        = local.common_tags

  depends_on = [module.vpc]
}

# Configure kubectl provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_id,
      "--region",
      var.aws_region
    ]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_id,
        "--region",
        var.aws_region
      ]
    }
  }
}

# KMS Module for Vault Auto-Unseal
module "kms" {
  source = "../../modules/kms"

  key_name        = "${var.project_name}-${var.environment}-vault-unseal"
  key_description = "KMS key for HashiCorp Vault auto-unseal in ${var.environment}"
  
  vault_namespace        = var.vault_namespace
  vault_service_account  = "vault"
  oidc_provider_arn      = module.eks.oidc_provider_arn
  
  environment = var.environment
  tags        = local.common_tags

  depends_on = [module.eks]
}

# EBS CSI Driver Module
module "ebs_csi_driver" {
  source = "../../modules/ebs-csi-driver"

  cluster_name   = module.eks.cluster_id
  environment    = var.environment
  set_as_default = true

  depends_on = [module.eks]
}

# Vault Module
module "vault" {
  source = "../../modules/vault"

  vault_namespace     = var.vault_namespace
  vault_release_name  = "vault"
  vault_replicas      = var.vault_replicas
  vault_storage_size  = var.vault_storage_size
  storage_class       = module.ebs_csi_driver.storage_class_name  
  kms_key_id          = module.kms.kms_key_id
  vault_kms_role_arn  = module.kms.vault_kms_role_arn
  aws_region          = var.aws_region
  enable_ui           = true
  enable_audit_logs   = true
  injector_enabled    = true
  metrics_enabled     = true
  environment         = var.environment
  tags                = local.common_tags

  depends_on = [
    module.kms,
    module.ebs_csi_driver  # ADD THIS
  ]
}


