#!/bin/bash
# Vault GitOps Platform - Teardown Script
# Author: Tobi Akinlade
# Purpose: Automated infrastructure cleanup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}Vault GitOps Platform - Teardown${NC}"
echo -e "${RED}========================================${NC}"
echo

# Warning
echo -e "${RED}WARNING: This will destroy all infrastructure!${NC}"
echo -e "${RED}This action cannot be undone.${NC}"
echo
read -p "Are you sure you want to proceed? (type 'yes' to confirm): " -r
echo

if [[ ! $REPLY == "yes" ]]; then
    echo -e "${YELLOW}Teardown cancelled${NC}"
    exit 0
fi

# Set environment
ENVIRONMENT=${1:-dev}
PROJECT_ROOT=$(pwd)
TF_DIR="${PROJECT_ROOT}/terraform/environments/${ENVIRONMENT}"

if [ ! -d "$TF_DIR" ]; then
    echo -e "${RED}Error: Environment ${ENVIRONMENT} does not exist${NC}"
    exit 1
fi

cd "$TF_DIR"

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo -e "${RED}Error: Terraform not initialized${NC}"
    exit 1
fi

# Get cluster name for cleanup
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")

if [ -n "$CLUSTER_NAME" ]; then
    # Clean up Kubernetes resources first
    echo -e "${YELLOW}Cleaning up Kubernetes resources...${NC}"
    
    # Delete ArgoCD if it exists
    if kubectl get namespace argocd &> /dev/null; then
        echo -e "${YELLOW}Deleting ArgoCD...${NC}"
        kubectl delete namespace argocd --ignore-not-found=true
        echo -e "${GREEN}✓ ArgoCD deleted${NC}"
    fi
    
    # Delete Vault if it exists
    if kubectl get namespace vault &> /dev/null; then
        echo -e "${YELLOW}Deleting Vault...${NC}"
        helm uninstall vault -n vault || true
        kubectl delete namespace vault --ignore-not-found=true
        echo -e "${GREEN}✓ Vault deleted${NC}"
    fi
    
    # Wait for resources to be deleted
    echo -e "${YELLOW}Waiting for resources to be deleted (this may take a few minutes)...${NC}"
    sleep 30
    
    # Delete any load balancers
    echo -e "${YELLOW}Cleaning up load balancers...${NC}"
    aws elb describe-load-balancers --region "${AWS_REGION:-eu-west-2}" \
        --query "LoadBalancerDescriptions[?contains(VPCId, '$(terraform output -raw vpc_id 2>/dev/null || echo "")')].[LoadBalancerName]" \
        --output text 2>/dev/null | while read lb; do
        if [ -n "$lb" ]; then
            echo "Deleting load balancer: $lb"
            aws elb delete-load-balancer --load-balancer-name "$lb" --region "${AWS_REGION:-eu-west-2}" || true
        fi
    done
    
    # Delete any target groups
    echo -e "${YELLOW}Cleaning up target groups...${NC}"
    aws elbv2 describe-target-groups --region "${AWS_REGION:-eu-west-2}" 2>/dev/null | \
        jq -r '.TargetGroups[].TargetGroupArn' 2>/dev/null | while read tg; do
        if [ -n "$tg" ]; then
            echo "Deleting target group: $tg"
            aws elbv2 delete-target-group --target-group-arn "$tg" --region "${AWS_REGION:-eu-west-2}" || true
        fi
    done
    
    echo -e "${GREEN}✓ Kubernetes resources cleaned up${NC}"
    echo
fi

# Destroy infrastructure
echo -e "${YELLOW}Destroying infrastructure with Terraform...${NC}"
terraform destroy -auto-approve
echo -e "${GREEN}✓ Infrastructure destroyed${NC}"
echo

# Clean up local files
echo -e "${YELLOW}Cleaning up local files...${NC}"
rm -f tfplan
rm -f .terraform.lock.hcl
echo -e "${GREEN}✓ Local files cleaned up${NC}"
echo

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Teardown Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo
echo -e "All infrastructure has been destroyed."
echo -e "You can redeploy by running: ${YELLOW}./scripts/setup.sh${NC}"
