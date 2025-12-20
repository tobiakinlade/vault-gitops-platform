# Getting Started Guide

This guide will walk you through deploying the complete Vault GitOps platform from scratch.

## Prerequisites

### Required Tools

```bash
# Check tool versions
terraform --version    # >= 1.6.0
aws --version          # AWS CLI v2
kubectl version        # >= 1.28
helm version           # >= 3.12
jq --version          # For JSON processing
vault --version       # Vault CLI (optional, for management)
```

### AWS Credentials

Ensure AWS credentials are configured:

```bash
aws configure
# or
export AWS_PROFILE=your-profile
```

Required IAM permissions:
- VPC management
- EKS cluster creation
- EC2 instance management
- KMS key management
- CloudWatch Logs
- S3 and DynamoDB (for Terraform state)

## Step-by-Step Deployment

### Step 1: Setup Terraform Backend

```bash
# From project root
cd vault-gitops-platform

# Set environment
export AWS_REGION=eu-west-2
export ENVIRONMENT=dev

# Run backend setup
./scripts/setup-backend.sh
```

This creates:
- S3 bucket for Terraform state
- DynamoDB table for state locking

### Step 2: Configure Variables

```bash
cd terraform/environments/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your preferences
vim terraform.tfvars
```

Key variables to review:
- `aws_region` - Your AWS region
- `project_name` - Unique project identifier
- `node_instance_types` - EC2 instance types for EKS
- `single_nat_gateway` - Set to `true` for dev (cost savings)

### Step 3: Enable Terraform Backend

Uncomment the backend configuration in `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "vault-terraform-state-dev"
    key            = "vault-platform/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "vault-terraform-locks"
  }
}
```

### Step 4: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (takes 15-20 minutes)
terraform apply
```

What gets created:
- VPC with public/private subnets across 3 AZs
- NAT Gateway(s) for private subnet internet access
- EKS cluster with managed node groups
- KMS key for Vault auto-unseal
- IAM roles and policies
- Security groups

### Step 5: Configure kubectl

```bash
# Get the kubeconfig command from Terraform output
terraform output configure_kubectl

# Run the command
aws eks update-kubeconfig --name vault-demo-dev-cluster --region eu-west-2

# Verify connection
kubectl get nodes
```

Expected output:
```
NAME                                        STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.eu-west-2.compute.internal   Ready    <none>   5m    v1.28.x
ip-10-0-2-xxx.eu-west-2.compute.internal   Ready    <none>   5m    v1.28.x
ip-10-0-3-xxx.eu-west-2.compute.internal   Ready    <none>   5m    v1.28.x
```

### Step 6: Verify Vault Deployment

```bash
# Check Vault pods
kubectl get pods -n vault

# Expected output
NAME      READY   STATUS    RESTARTS   AGE
vault-0   0/1     Running   0          2m
vault-1   0/1     Running   0          2m
vault-2   0/1     Running   0          2m
```

Note: Pods show 0/1 ready because Vault needs initialization.

### Step 7: Generate TLS Certificates

Before initializing Vault, we need TLS certificates:

```bash
# Create a temporary directory for certificates
mkdir -p /tmp/vault-tls
cd /tmp/vault-tls

# Generate CA private key
openssl genrsa -out ca.key 2048

# Generate CA certificate
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -out ca.crt \
    -subj "/C=UK/ST=England/L=London/O=DevOps/CN=Vault CA"

# Generate server private key
openssl genrsa -out tls.key 2048

# Generate certificate signing request
openssl req -new -key tls.key -out tls.csr \
    -subj "/C=UK/ST=England/L=London/O=DevOps/CN=vault"

# Create extensions file
cat > tls.ext << EOF
subjectAltName = DNS:vault,DNS:vault.vault,DNS:vault.vault.svc,DNS:vault.vault.svc.cluster.local,DNS:localhost,IP:127.0.0.1
extendedKeyUsage = serverAuth,clientAuth
EOF

# Sign the certificate
openssl x509 -req -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out tls.crt -days 365 -sha256 -extfile tls.ext

# Create Kubernetes secret
kubectl create secret generic vault-tls \
    -n vault \
    --from-file=ca.crt=ca.crt \
    --from-file=tls.crt=tls.crt \
    --from-file=tls.key=tls.key

# Restart Vault pods to pick up the certificates
kubectl delete pod -n vault -l app.kubernetes.io/name=vault

# Wait for pods to be running
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=300s
```

### Step 8: Initialize Vault

```bash
# From project root
cd vault-gitops-platform

# Run initialization script
./scripts/vault-init.sh
```

This script:
- Initializes Vault with 5 key shares, threshold of 3
- Saves unseal keys and root token to `vault-init.json`
- Enables audit logging
- Configures Kubernetes authentication
- Enables KV, PKI, and Database secrets engines

**IMPORTANT**: Immediately backup `vault-init.json` to a secure location and delete it from your working directory.

### Step 9: Access Vault UI

```bash
# Get the UI service details
kubectl get svc -n vault vault-ui

# Option 1: Port forward (for testing)
kubectl port-forward -n vault svc/vault-ui 8200:8200

# Option 2: Access via Load Balancer (production)
kubectl get svc -n vault vault-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open browser to `http://localhost:8200` (or LoadBalancer URL) and login with root token.

## Verification Steps

### Check All Components

```bash
# 1. VPC and Networking
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vault-demo-dev-vpc"

# 2. EKS Cluster
aws eks describe-cluster --name vault-demo-dev-cluster --region eu-west-2

# 3. KMS Key
aws kms describe-key --key-id alias/vault-demo-dev-vault-unseal

# 4. Vault Status
kubectl exec -n vault vault-0 -- vault status

# 5. Vault Logs
kubectl logs -n vault vault-0 --tail=50
```

### Test Vault Operations

```bash
# Set Vault address
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<root-token-from-vault-init.json>

# Port forward to Vault
kubectl port-forward -n vault svc/vault-active 8200:8200 &

# Write a secret
vault kv put secret/demo password=supersecret

# Read the secret
vault kv get secret/demo

# List secrets
vault kv list secret/
```

## Common Issues and Solutions

### Issue: Vault pods stuck in Init state

**Solution**: Check TLS certificates exist:
```bash
kubectl get secret vault-tls -n vault
```

If missing, regenerate certificates (Step 7).

### Issue: Cannot connect to EKS cluster

**Solution**: Update kubeconfig:
```bash
aws eks update-kubeconfig --name vault-demo-dev-cluster --region eu-west-2
```

### Issue: Terraform state locked

**Solution**: Force unlock (use with caution):
```bash
terraform force-unlock <lock-id>
```

### Issue: High AWS costs

**Solutions**:
- Use single NAT Gateway for dev: `single_nat_gateway = true`
- Use smaller instance types: `node_instance_types = ["t3.small"]`
- Reduce node count: `node_desired_size = 2`
- Delete resources when not in use: `./scripts/cleanup.sh`

## Next Steps

1. **Configure Vault Policies**: See [docs/vault-policies.md](vault-policies.md)
2. **Setup GitOps with ArgoCD**: See [docs/gitops-setup.md](gitops-setup.md)
3. **Deploy Demo Application**: See [gitops/applications/demo-app/README.md](../gitops/applications/demo-app/README.md)
4. **Configure Observability**: See [docs/observability.md](observability.md)
5. **Setup Disaster Recovery**: See [docs/disaster-recovery.md](disaster-recovery.md)

## Cost Optimization

### Development Environment

Current setup costs approximately **£180-220/month**:
- EKS Control Plane: £60/month
- EC2 Instances (3x t3.medium): £90/month
- NAT Gateway (single): £35/month
- EBS Volumes: £8/month
- Data Transfer: £7/month

**Optimization tips**:
- Use Spot instances for non-critical workloads
- Schedule dev environment shutdown after hours
- Use single NAT Gateway
- Right-size EBS volumes

## Support and Troubleshooting

For issues:
1. Check logs: `kubectl logs -n vault <pod-name>`
2. Check events: `kubectl get events -n vault --sort-by='.lastTimestamp'`
3. Review Terraform state: `terraform show`
4. Consult [Troubleshooting Guide](troubleshooting.md)

## Cleanup

To destroy all resources:

```bash
./scripts/cleanup.sh
```

**WARNING**: This is irreversible and will delete all data.
