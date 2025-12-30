#!/bin/bash

echo "=== Updating Vault Policy ==="
echo ""

# Get Vault details
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
VAULT_TOKEN=$(kubectl exec -n vault ${VAULT_POD} -- cat /vault/data/init.txt 2>/dev/null | grep "Initial Root Token:" | awk '{print $NF}')

echo "Vault Pod: ${VAULT_POD}"
echo ""

# Login
echo "Step 1: Logging into Vault..."
kubectl exec -n vault ${VAULT_POD} -- vault login ${VAULT_TOKEN} >/dev/null 2>&1
echo "✅ Logged in"
echo ""

# Create policy file
echo "Step 2: Creating policy file..."
cat > /tmp/tax-calculator-policy.hcl <<'EOF'
# Database credentials
path "database/creds/tax-calculator-role" {
  capabilities = ["read"]
}

# Transit encryption
path "transit/encrypt/tax-calculator" {
  capabilities = ["create", "update"]
}

path "transit/decrypt/tax-calculator" {
  capabilities = ["create", "update"]
}

# Token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF

echo "✅ Policy file created"
echo ""

# Copy to vault pod
echo "Step 3: Copying policy to Vault pod..."
kubectl cp /tmp/tax-calculator-policy.hcl vault/${VAULT_POD}:/tmp/policy.hcl
echo "✅ Copied"
echo ""

# Write policy
echo "Step 4: Writing policy to Vault..."
kubectl exec -n vault ${VAULT_POD} -- vault policy write tax-calculator /tmp/policy.hcl
echo "✅ Policy written"
echo ""

# Verify
echo "Step 5: Verifying policy..."
kubectl exec -n vault ${VAULT_POD} -- vault policy read tax-calculator
echo ""

# Update role TTL
echo "Step 6: Updating Kubernetes auth role..."
kubectl exec -n vault ${VAULT_POD} -- vault write auth/kubernetes/role/tax-calculator \
  bound_service_account_names=tax-calculator \
  bound_service_account_namespaces=tax-calculator \
  policies=tax-calculator \
  ttl=24h \
  max_ttl=72h

echo "✅ Role updated"
echo ""

# Clean up
kubectl exec -n vault ${VAULT_POD} -- rm /tmp/policy.hcl
rm /tmp/tax-calculator-policy.hcl

# Restart backend
echo "Step 7: Restarting backend..."
kubectl rollout restart deployment backend -n tax-calculator

echo "Waiting for rollout..."
kubectl rollout status deployment backend -n tax-calculator --timeout=300s

echo ""
echo "=== Complete ==="
echo ""

# Check logs
BACKEND_POD=$(kubectl get pods -n tax-calculator -l component=backend -o jsonpath='{.items[0].metadata.name}')
echo "Backend logs:"
kubectl logs ${BACKEND_POD} -n tax-calculator --tail=20

echo ""
FRONTEND_URL=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Test application: http://${FRONTEND_URL}"
