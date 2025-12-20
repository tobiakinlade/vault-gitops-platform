#!/bin/bash
# Vault GitOps Platform - Setup Script
# Author: Tobi Akinlade
# Purpose: Automated infrastructure deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Vault GitOps Platform - Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: terraform is not installed${NC}"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-eu-west-2}
echo -e "${GREEN}✓ AWS Account: ${AWS_ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ AWS Region: ${AWS_REGION}${NC}"
echo

# Set environment
ENVIRONMENT=${1:-dev}
PROJECT_ROOT=$(pwd)
TF_DIR="${PROJECT_ROOT}/terraform/environments/${ENVIRONMENT}"

if [ ! -d "$TF_DIR" ]; then
    echo -e "${RED}Error: Environment ${ENVIRONMENT} does not exist${NC}"
    exit 1
fi

cd "$TF_DIR"

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Creating terraform.tfvars from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${GREEN}✓ terraform.tfvars created${NC}"
    echo -e "${YELLOW}Please review and update terraform.tfvars with your values${NC}"
    echo
fi

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo

# Validate configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate
echo -e "${GREEN}✓ Configuration valid${NC}"
echo

# Plan deployment
echo -e "${YELLOW}Creating deployment plan...${NC}"
terraform plan -out=tfplan
echo -e "${GREEN}✓ Plan created${NC}"
echo

# Ask for confirmation
echo -e "${YELLOW}Ready to deploy infrastructure?${NC}"
echo -e "This will create:"
echo -e "  - VPC with public/private subnets"
echo -e "  - EKS cluster with managed node groups"
echo -e "  - KMS keys for encryption"
echo -e "  - Security groups and IAM roles"
echo
read -p "Continue? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

# Apply configuration
echo -e "${YELLOW}Deploying infrastructure...${NC}"
terraform apply tfplan
echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo

# Configure kubectl
echo -e "${YELLOW}Configuring kubectl...${NC}"
CLUSTER_NAME=$(terraform output -raw cluster_name)
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
echo -e "${GREEN}✓ kubectl configured${NC}"
echo

# Verify cluster access
echo -e "${YELLOW}Verifying cluster access...${NC}"
kubectl get nodes
echo -e "${GREEN}✓ Cluster accessible${NC}"
echo

# Display outputs
echo
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "Next steps:"
echo -e "1. Deploy Vault:"
echo -e "   ${YELLOW}cd ${PROJECT_ROOT}${NC}"
echo -e "   ${YELLOW}helm repo add hashicorp https://helm.releases.hashicorp.com${NC}"
echo -e "   ${YELLOW}helm install vault hashicorp/vault -n vault --create-namespace \\${NC}"
echo -e "   ${YELLOW}  --set server.ha.enabled=true \\${NC}"
echo -e "   ${YELLOW}  --set server.ha.replicas=3${NC}"
echo
echo -e "2. Initialize Vault:"
echo -e "   ${YELLOW}kubectl exec -n vault vault-0 -- vault operator init${NC}"
echo
echo -e "3. Deploy ArgoCD:"
echo -e "   ${YELLOW}kubectl create namespace argocd${NC}"
echo -e "   ${YELLOW}kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml${NC}"
echo
echo -e "${GREEN}Infrastructure deployment complete!${NC}"
