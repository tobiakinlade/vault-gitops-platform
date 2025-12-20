# Local Development Setup with kind (Kubernetes in Docker)
# 100% FREE - Runs on your local machine

## Overview

This setup uses **kind** (Kubernetes in Docker) to run Vault locally. Perfect for:
- Learning and experimentation
- Testing configurations before AWS deployment
- CI/CD pipeline testing
- Zero cost development

## Prerequisites

```bash
# Install Docker
# macOS: Download Docker Desktop
# Linux: sudo apt install docker.io
# Windows: Download Docker Desktop

# Install kind
# macOS/Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Or use package managers
# macOS: brew install kind
# Linux: sudo apt install kind

# Install kubectl
# macOS: brew install kubectl
# Linux: sudo apt install kubectl
# Windows: choco install kubernetes-cli

# Install Helm
# macOS: brew install helm
# Linux: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install Vault CLI (optional)
# macOS: brew install vault
# Linux: wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
```

## Quick Start (5 minutes)

```bash
# 1. Create kind cluster
cat <<EOF | kind create cluster --name vault-demo --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30000
    hostPort: 8200
    protocol: TCP
- role: worker
- role: worker
EOF

# 2. Verify cluster
kubectl cluster-info
kubectl get nodes

# 3. Create Vault namespace
kubectl create namespace vault

# 4. Install Vault with Helm
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# 5. Install Vault (dev mode for local)
helm install vault hashicorp/vault \
  --namespace vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root" \
  --set "ui.enabled=true" \
  --set "ui.serviceType=NodePort" \
  --set "ui.serviceNodePort=30000"

# 6. Wait for Vault to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n vault --timeout=120s

# 7. Access Vault UI
echo "Vault UI: http://localhost:8200"
echo "Token: root"

# 8. Port forward (if NodePort doesn't work)
kubectl port-forward -n vault svc/vault 8200:8200 &

# 9. Set Vault environment
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'

# 10. Test Vault
vault status
vault kv put secret/demo password="hello-world"
vault kv get secret/demo
```

## Configuration Options

### Option 1: Dev Mode (Simplest - Data not persisted)

```yaml
# vault-dev-values.yaml
server:
  dev:
    enabled: true
    devRootToken: "root"
  
  dataStorage:
    enabled: false  # Dev mode uses in-memory storage

ui:
  enabled: true
  serviceType: NodePort
  serviceNodePort: 30000

injector:
  enabled: true
```

Deploy:
```bash
helm install vault hashicorp/vault -n vault -f vault-dev-values.yaml
```

### Option 2: HA Mode with File Storage (Data persisted)

```yaml
# vault-ha-values.yaml
server:
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      config: |
        ui = true
        
        listener "tcp" {
          tls_disable = 1
          address = "[::]:8200"
          cluster_address = "[::]:8201"
        }
        
        storage "raft" {
          path = "/vault/data"
        }
        
        service_registration "kubernetes" {}

  dataStorage:
    enabled: true
    size: 1Gi
    storageClass: standard

ui:
  enabled: true
  serviceType: NodePort
  serviceNodePort: 30000

injector:
  enabled: true
```

Deploy:
```bash
helm install vault hashicorp/vault -n vault -f vault-ha-values.yaml

# Initialize Vault
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=1 \
  -key-threshold=1 \
  -format=json > vault-keys.json

# Unseal all pods
VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" vault-keys.json)
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl exec -n vault vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY
kubectl exec -n vault vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY
```

## Demo Application with Vault Integration

```yaml
# demo-app.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-app
  namespace: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "demo-app"
        vault.hashicorp.com/agent-inject-secret-credentials: "secret/data/demo-app"
    spec:
      serviceAccountName: demo-app
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        command: ["/bin/sh"]
        args:
          - -c
          - |
            while true; do
              echo "Reading secrets from /vault/secrets/credentials"
              cat /vault/secrets/credentials
              sleep 30
            done
```

Deploy:
```bash
# Configure Vault auth
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create policy
kubectl exec -n vault vault-0 -- vault policy write demo-app - <<EOF
path "secret/data/demo-app" {
  capabilities = ["read"]
}
EOF

# Create role
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/demo-app \
  bound_service_account_names=demo-app \
  bound_service_account_namespaces=default \
  policies=demo-app \
  ttl=24h

# Create secret
kubectl exec -n vault vault-0 -- vault kv put secret/demo-app \
  username="demo" \
  password="secret123"

# Deploy app
kubectl apply -f demo-app.yaml

# Check logs
kubectl logs -l app=demo-app -c app -f
```

## Features Demonstrated

✅ Vault installation and configuration
✅ High Availability (3 replicas)
✅ Vault Agent Injector
✅ Kubernetes authentication
✅ Secret injection into pods
✅ Policy-based access control

## Advantages of Local Setup

| Feature | Local (kind) | AWS EKS |
|---------|--------------|---------|
| **Cost** | £0 | £90-220/month |
| **Setup Time** | 5 minutes | 20 minutes |
| **Experimentation** | Unlimited | Costs money |
| **CI/CD Testing** | Fast & free | Slower & costly |
| **Learning** | Perfect | Overkill |
| **Production-like** | Basic | Full |
| **Multi-region** | No | Yes |

## Comparison Table

### When to Use Each Setup

| Use Case | Recommended Setup |
|----------|-------------------|
| **Learning Vault basics** | Local (kind) |
| **Testing configurations** | Local (kind) |
| **Interview demo** | AWS (dev-lite) |
| **Production practice** | AWS (full dev) |
| **CI/CD pipelines** | Local (kind) |
| **Team collaboration** | AWS (dev) |
| **Compliance testing** | AWS (full dev) |
| **Cost-free learning** | Local (kind) |

## Cleanup

```bash
# Delete kind cluster
kind delete cluster --name vault-demo

# That's it! Everything is gone.
```

## Transitioning to AWS

Once you're comfortable with the local setup, transition to AWS:

```bash
# Your local learnings transfer directly
# The same Helm values work
# The same policies work
# The same authentication methods work

# Just need to:
# 1. Replace file storage with Raft/DynamoDB
# 2. Add KMS auto-unseal
# 3. Configure AWS IAM (IRSA)
# 4. Enable TLS
```

## Learning Path

```
Week 1: Local Setup (kind)
├─ Day 1: Install Vault, basic operations
├─ Day 2: Policies and authentication
├─ Day 3: Secrets engines (KV, Database)
├─ Day 4: Vault Agent Injector
└─ Day 5: Demo application

Week 2: AWS Deployment
├─ Deploy to AWS using dev-lite
├─ Configure KMS auto-unseal
├─ Setup IRSA
└─ Add TLS

Week 3: Production Patterns
├─ High Availability
├─ Disaster Recovery
├─ Observability
└─ GitOps
```

## Common Issues

### Issue: Docker not running
```bash
# Start Docker
# macOS/Windows: Open Docker Desktop
# Linux: sudo systemctl start docker
```

### Issue: kind cluster won't start
```bash
# Delete and recreate
kind delete cluster --name vault-demo
kind create cluster --name vault-demo
```

### Issue: Can't access Vault UI
```bash
# Use port-forward instead of NodePort
kubectl port-forward -n vault svc/vault 8200:8200
```

## Resources

- [kind Documentation](https://kind.sigs.k8s.io/)
- [Vault on Kubernetes](https://www.vaultproject.io/docs/platform/k8s)
- [Vault Agent Injector](https://www.vaultproject.io/docs/platform/k8s/injector)

---

**Perfect for learners: Zero cost, quick setup, full features!** 🎓
