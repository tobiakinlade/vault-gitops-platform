#!/bin/bash
# Cleanup Script - Destroy all infrastructure
# WARNING: This will delete all resources created by Terraform

set -e

AWS_REGION="${AWS_REGION:-eu-west-2}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

echo "======================================"
echo "⚠️  WARNING: Infrastructure Cleanup"
echo "======================================"
echo "This will destroy ALL resources in ${ENVIRONMENT} environment"
echo "Region: ${AWS_REGION}"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "${CONFIRM}" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Starting cleanup process..."

# Navigate to environment directory
cd "$(dirname "$0")/../terraform/environments/${ENVIRONMENT}"

# Destroy Terraform resources
echo "Destroying Terraform resources..."
terraform destroy -auto-approve

# Delete Vault PVCs (these might not be cleaned up automatically)
echo "Checking for remaining Vault PVCs..."
if kubectl get pvc -n vault &>/dev/null; then
    echo "Deleting Vault PVCs..."
    kubectl delete pvc -n vault --all --wait=true
fi

# Delete Vault namespace
echo "Deleting Vault namespace..."
kubectl delete namespace vault --wait=true || true

echo ""
echo "======================================"
echo "Cleanup Complete!"
echo "======================================"
echo ""
echo "If you want to delete the S3 backend, run:"
echo "  aws s3 rb s3://vault-terraform-state-${ENVIRONMENT} --force"
echo "  aws dynamodb delete-table --table-name vault-terraform-locks --region ${AWS_REGION}"
echo ""
