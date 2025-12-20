# Vault GitOps Platform - Setup Guide

This guide will walk you through deploying the complete Vault GitOps platform from scratch.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Infrastructure Deployment](#infrastructure-deployment)
4. [Vault Initialization](#vault-initialization)
5. [Demo Application](#demo-application)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools
```bash
# Check versions
aws --version          # AWS CLI >= 2.0
terraform --version    # Terraform >= 1.3
kubectl version       # kubectl >= 1.28
helm version          # Helm >= 3.12
```

### AWS Setup
1. **Create AWS Account** (if needed)
2. **Configure AWS CLI**:
```bash
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region: eu-west-2
# Default output format: json
```

3. **Verify AWS Access**:
```bash
aws sts get-caller-identity
```

### Clone Repository
```bash
git clone https://github.com/yourusername/vault-gitops-platform.git
cd vault-gitops-platform
```

## Initial Setup

### 1. Review Configuration

Edit `terraform/environments/dev/variables.tf`:

```hcl
variable "aws_region" {
  default = "eu-west-2"  # Change if needed
}

variable "project_name" {
  default = "vault-gitops"
}

variable "environment" {
  default = "dev"
}
```

### 2. Cost Estimation

**Monthly Costs (Dev Environment)**:
- EKS Control Plane: ~$73
- EC2 Instances (3x t3.medium): ~$75
- NAT Gateway (1): ~$32
- EBS Volumes: ~$15
- Total: ~$195/month

**Cost Optimization Tips**:
- Use spot instances for dev (set `capacity_type = "SPOT"`)
- Scale down when not in use
- Use single NAT gateway (already configured)

## Infrastructure Deployment

### Option 1: Automated Deployment (Recommended)

```bash
# Deploy everything
./scripts/deploy.sh dev eu-west-2
```

This script will:
1. ✅ Validate prerequisites
2. ✅ Initialize Terraform
3. ✅ Deploy infrastructure
4. ✅ Configure kubectl
5. ✅ Wait for resources

⏱️ **Estimated time**: 15-20 minutes

### Option 2: Manual Deployment

```bash
# Navigate to environment
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply changes
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region eu-west-2 --name vault-gitops-dev

# Verify nodes
kubectl get nodes
```

## Vault Initialization

### First-Time Setup

```bash
# Run initialization script
./scripts/init-vault.sh
```

**Important**: This script will:
1. Initialize Vault with recovery keys
2. Generate root token
3. Save credentials to `vault-credentials-TIMESTAMP.txt`

**🔐 CRITICAL**: Store credentials securely!

### Manual Initialization (Alternative)

```bash
# Initialize Vault
kubectl exec -n vault vault-0 -- vault operator init

# Save output securely!
```

### Verify Vault Status

```bash
# Check status
kubectl exec -n vault vault-0 -- vault status

# Expected output:
# Initialized: true
# Sealed: false (auto-unsealed by KMS)
```

## Demo Application

### 1. Configure Vault for Demo App

```bash
# Run configuration script
./scripts/configure-demo-app.sh
```

**Enter your root token when prompted**

This configures:
- ✅ KV v2 secrets engine
- ✅ Kubernetes auth method
- ✅ Demo app policy
- ✅ Demo secrets

### 2. Deploy Demo Application

```bash
# Deploy application
kubectl apply -f gitops/applications/demo-app/deployment.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app=demo-app -n demo --timeout=300s

# Check pods
kubectl get pods -n demo
```

### 3. Verify Secret Injection

```bash
# Get pod name
POD=$(kubectl get pod -n demo -l app=demo-app -o jsonpath='{.items[0].metadata.name}')

# Exec into pod
kubectl exec -n demo -it $POD -c demo-app -- sh

# Inside pod, check injected secrets
cat /vault/secrets/database-config
cat /vault/secrets/api-keys

# Exit pod
exit
```

Expected output shows environment variables with secrets from Vault!

## Verification

### Infrastructure Health

```bash
# Check all resources
kubectl get all -n vault
kubectl get all -n demo

# Check EKS nodes
kubectl get nodes -o wide

# Check storage
kubectl get pvc -n vault
```

### Vault Health

```bash
# Port-forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

# Check status
export VAULT_ADDR='https://localhost:8200'
export VAULT_SKIP_VERIFY=1
vault status

# Login with root token
vault login <YOUR_ROOT_TOKEN>

# List secrets
vault kv list secret/demo-app
vault kv get secret/demo-app/database
```

### Audit Logs

```bash
# View Vault audit logs
aws logs tail /aws/vault/vault-gitops-dev/audit --follow

# View EKS control plane logs
aws logs tail /aws/eks/vault-gitops-dev/cluster --follow
```

## Troubleshooting

### Vault Pods Not Starting

```bash
# Check pod logs
kubectl logs -n vault vault-0

# Check events
kubectl describe pod -n vault vault-0

# Check IRSA
kubectl describe sa -n vault vault

# Verify KMS permissions
aws iam get-role --role-name vault-gitops-dev-vault-kms-role
```

### KMS Auto-Unseal Issues

```bash
# Check KMS key
aws kms describe-key --key-id <KEY_ID>

# Verify IAM policy
aws iam get-role-policy --role-name vault-gitops-dev-vault-kms-role --policy-name vault-gitops-dev-vault-kms-policy

# Check Vault logs for KMS errors
kubectl logs -n vault vault-0 | grep -i kms
```

### Demo App Issues

```bash
# Check pod status
kubectl describe pod -n demo <POD_NAME>

# Check Vault agent sidecar logs
kubectl logs -n demo <POD_NAME> -c vault-agent

# Verify Kubernetes auth
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/role/demo-app
```

### Network Issues

```bash
# Test DNS
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- nslookup vault.vault.svc.cluster.local

# Check security groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=*vault-gitops-dev*"

# Check VPC Flow Logs
aws logs tail /aws/vpc/vault-gitops-dev-flow-logs --follow
```

## Day 2 Operations

### Backup Vault Data

```bash
# Create snapshot
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/backup.snap

# Copy to local
kubectl cp vault/vault-0:/tmp/backup.snap ./backup-$(date +%Y%m%d).snap

# Upload to S3 (recommended)
aws s3 cp ./backup-$(date +%Y%m%d).snap s3://your-backup-bucket/vault/
```

### Rotate Secrets

```bash
# Update secret
kubectl exec -n vault vault-0 -- vault kv put secret/demo-app/database \
    host="mysql.database.svc.cluster.local" \
    port="3306" \
    username="demo_user" \
    password="NEW_PASSWORD" \
    database="demo_db"

# Restart pods to get new secrets
kubectl rollout restart deployment/demo-app -n demo
```

### Scale Infrastructure

```bash
# Scale node group
cd terraform/environments/dev
terraform apply -var="node_groups.general.desired_size=5"

# Scale Vault replicas
terraform apply -var="vault_replicas=5"
```

### Upgrade Vault

```bash
# Update version
cd terraform/environments/dev
# Edit variables.tf: vault_version = "1.19.0"

# Apply changes
terraform apply

# Verify
kubectl exec -n vault vault-0 -- vault version
```

## Cleanup

### Delete Everything

```bash
# Run destroy script
./scripts/destroy.sh dev

# Type 'destroy' to confirm
```

**⚠️ Warning**: This permanently deletes all infrastructure and data!

## Next Steps

1. **Set up remote state**: Configure S3 backend in `main.tf`
2. **Add monitoring**: Deploy Prometheus/Grafana
3. **Configure GitOps**: Set up ArgoCD for automated deployments
4. **Enable additional engines**: PKI, Database, Transit
5. **Create production environment**: Duplicate to `terraform/environments/prod`

## Support

- 📚 Documentation: [Vault Docs](https://www.vaultproject.io/docs)
- 🐛 Issues: GitHub Issues
- 💬 Discussions: GitHub Discussions

## Interview Preparation

When discussing this project:

1. **Start with the problem**: "Managing secrets across 20+ microservices"
2. **Explain the architecture**: HA Vault, KMS auto-unseal, GitOps
3. **Highlight security**: TLS, IRSA, audit logging, encryption
4. **Show scalability**: Modular Terraform, multi-environment
5. **Demonstrate DevOps practices**: IaC, automation, monitoring
6. **Discuss trade-offs**: Cost vs. availability, complexity vs. simplicity

**Key Metrics to Mention**:
- 3-node HA cluster, 99.9% uptime
- Auto-unseal with AWS KMS
- 90-day audit retention
- Multi-AZ deployment
- Cost-optimized for dev (~$195/month)

---

**Author**: Tobi Akinlade  
**Last Updated**: December 2025  
**Version**: 1.0.0
