#!/bin/bash
# Setup Terraform Backend - S3 and DynamoDB
# Run this script once before running terraform init

set -e

# Configuration
AWS_REGION="${AWS_REGION:-eu-west-2}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
BUCKET_NAME="vault-terraform-state-${ENVIRONMENT}"
DYNAMODB_TABLE="vault-terraform-locks"

echo "======================================"
echo "Setting up Terraform Backend"
echo "======================================"
echo "Region: ${AWS_REGION}"
echo "Environment: ${ENVIRONMENT}"
echo "S3 Bucket: ${BUCKET_NAME}"
echo "DynamoDB Table: ${DYNAMODB_TABLE}"
echo "======================================"

# Check if bucket exists
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket: ${BUCKET_NAME}"
    
    # Create bucket with location constraint for regions other than us-east-1
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${AWS_REGION}" \
        --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    
    # Enable versioning
    echo "Enabling versioning on S3 bucket..."
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    echo "Enabling encryption on S3 bucket..."
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'
    
    # Block public access
    echo "Blocking public access on S3 bucket..."
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    echo "✅ S3 bucket created and configured: ${BUCKET_NAME}"
else
    echo "✅ S3 bucket already exists: ${BUCKET_NAME}"
fi

# Check if DynamoDB table exists
if ! aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" &>/dev/null; then
    echo "Creating DynamoDB table: ${DYNAMODB_TABLE}"
    
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}"
    
    echo "Waiting for DynamoDB table to become active..."
    aws dynamodb wait table-exists \
        --table-name "${DYNAMODB_TABLE}" \
        --region "${AWS_REGION}"
    
    echo "✅ DynamoDB table created: ${DYNAMODB_TABLE}"
else
    echo "✅ DynamoDB table already exists: ${DYNAMODB_TABLE}"
fi

echo ""
echo "======================================"
echo "Backend Setup Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Uncomment the backend configuration in terraform/environments/${ENVIRONMENT}/main.tf"
echo "2. Run: cd terraform/environments/${ENVIRONMENT}"
echo "3. Run: terraform init"
echo "4. Run: terraform plan"
echo "5. Run: terraform apply"
echo ""
