# Terraform Backend Configuration
# This file should be copied to each environment directory (dev/prod)

terraform {
  backend "s3" {
    # Update these values based on your environment
    bucket         = "vault-terraform-state-${var.environment}"  # e.g., vault-terraform-state-dev
    key            = "vault-platform/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "vault-terraform-locks"
    
    # Optional: Add versioning for state file recovery
    # versioning    = true
  }
  
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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Note: Before first run, create the S3 bucket and DynamoDB table:
# 
# aws s3api create-bucket \
#   --bucket vault-terraform-state-dev \
#   --region eu-west-2 \
#   --create-bucket-configuration LocationConstraint=eu-west-2
#
# aws s3api put-bucket-versioning \
#   --bucket vault-terraform-state-dev \
#   --versioning-configuration Status=Enabled
#
# aws s3api put-bucket-encryption \
#   --bucket vault-terraform-state-dev \
#   --server-side-encryption-configuration '{
#     "Rules": [{
#       "ApplyServerSideEncryptionByDefault": {
#         "SSEAlgorithm": "AES256"
#       }
#     }]
#   }'
#
# aws dynamodb create-table \
#   --table-name vault-terraform-locks \
#   --attribute-definitions AttributeName=LockID,AttributeType=S \
#   --key-schema AttributeName=LockID,KeyType=HASH \
#   --billing-mode PAY_PER_REQUEST \
#   --region eu-west-2
