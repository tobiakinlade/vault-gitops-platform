#!/bin/bash
# Initialize Vault Cluster
# This script initializes the Vault cluster and configures basic auth methods

set -e

VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_SERVICE="vault-active"
VAULT_ADDR="http://localhost:8200"

echo "======================================"
echo "Initializing Vault Cluster"
echo "======================================"

# Check if kubectl is configured
if ! kubectl get nodes &>/dev/null; then
    echo "❌ kubectl is not configured. Please run:"
    echo "   aws eks update-kubeconfig --name <cluster-name> --region <region>"
    exit 1
fi

# Check if Vault pods are running
echo "Checking Vault pod status..."
if ! kubectl get pods -n "${VAULT_NAMESPACE}" | grep -q "vault-"; then
    echo "❌ Vault pods not found in namespace: ${VAULT_NAMESPACE}"
    exit 1
fi

echo "✅ Vault pods found"

# Wait for Vault pods to be ready
echo "Waiting for Vault pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault -n "${VAULT_NAMESPACE}" --timeout=300s

# Port forward to Vault
echo "Setting up port forwarding to Vault..."
kubectl port-forward -n "${VAULT_NAMESPACE}" svc/"${VAULT_SERVICE}" 8200:8200 &
PORT_FORWARD_PID=$!
sleep 5

# Cleanup function
cleanup() {
    echo "Cleaning up port forward..."
    kill ${PORT_FORWARD_PID} 2>/dev/null || true
}
trap cleanup EXIT

export VAULT_ADDR="${VAULT_ADDR}"
export VAULT_SKIP_VERIFY=true

# Check Vault status
echo "Checking Vault status..."
if ! vault status &>/dev/null; then
    echo "Starting Vault initialization..."
    
    # Initialize Vault
    echo "Initializing Vault (this will create root token and unseal keys)..."
    INIT_OUTPUT=$(vault operator init -key-shares=5 -key-threshold=3 -format=json)
    
    # Save to file
    echo "${INIT_OUTPUT}" > vault-init.json
    chmod 600 vault-init.json
    
    echo "✅ Vault initialized successfully!"
    echo "⚠️  IMPORTANT: Root token and unseal keys saved to: vault-init.json"
    echo "⚠️  Store this file securely and delete it from this location!"
    
    # Extract root token
    ROOT_TOKEN=$(echo "${INIT_OUTPUT}" | jq -r '.root_token')
    echo "Root Token: ${ROOT_TOKEN}"
    
else
    echo "⚠️  Vault is already initialized"
    
    if [ ! -f "vault-init.json" ]; then
        echo "❌ vault-init.json not found. Cannot proceed without root token."
        exit 1
    fi
    
    ROOT_TOKEN=$(jq -r '.root_token' vault-init.json)
fi

# Login with root token
echo "Logging in to Vault..."
vault login "${ROOT_TOKEN}"

# Enable audit logging
echo "Enabling audit logging..."
if ! vault audit list | grep -q "file"; then
    vault audit enable file file_path=/vault/audit/vault_audit.log
    echo "✅ Audit logging enabled"
else
    echo "✅ Audit logging already enabled"
fi

# Enable Kubernetes auth
echo "Configuring Kubernetes authentication..."
if ! vault auth list | grep -q "kubernetes"; then
    vault auth enable kubernetes
    
    # Configure Kubernetes auth
    vault write auth/kubernetes/config \
        kubernetes_host="https://\$KUBERNETES_SERVICE_HOST:\$KUBERNETES_SERVICE_PORT"
    
    echo "✅ Kubernetes authentication enabled"
else
    echo "✅ Kubernetes authentication already enabled"
fi

# Enable KV v2 secrets engine
echo "Enabling KV v2 secrets engine..."
if ! vault secrets list | grep -q "secret/"; then
    vault secrets enable -path=secret kv-v2
    echo "✅ KV v2 secrets engine enabled at: secret/"
else
    echo "✅ KV v2 secrets engine already enabled"
fi

# Enable PKI secrets engine
echo "Enabling PKI secrets engine..."
if ! vault secrets list | grep -q "pki/"; then
    vault secrets enable pki
    vault secrets tune -max-lease-ttl=87600h pki
    echo "✅ PKI secrets engine enabled"
else
    echo "✅ PKI secrets engine already enabled"
fi

# Enable database secrets engine
echo "Enabling database secrets engine..."
if ! vault secrets list | grep -q "database/"; then
    vault secrets enable database
    echo "✅ Database secrets engine enabled"
else
    echo "✅ Database secrets engine already enabled"
fi

echo ""
echo "======================================"
echo "Vault Initialization Complete!"
echo "======================================"
echo ""
echo "Vault UI: kubectl port-forward -n ${VAULT_NAMESPACE} svc/vault-ui 8200:8200"
echo "Vault CLI: export VAULT_ADDR=http://localhost:8200"
echo "Root Token: ${ROOT_TOKEN}"
echo ""
echo "⚠️  Remember to:"
echo "1. Store vault-init.json securely"
echo "2. Delete vault-init.json from this location after backup"
echo "3. Revoke the root token after creating admin users"
echo ""

# Test a simple operation
echo "Testing Vault with a sample secret..."
vault kv put secret/demo password="test123"
vault kv get secret/demo
echo "✅ Vault is working correctly!"

echo ""
echo "Next steps:"
echo "1. Create policies: vault policy write <name> <file>"
echo "2. Create users/roles for applications"
echo "3. Configure dynamic secrets"
echo ""
