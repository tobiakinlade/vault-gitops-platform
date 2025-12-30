#!/bin/bash

echo "=== Complete Vault Database Configuration ==="
echo ""

# Get Vault details
VAULT_POD=$(kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
echo "Vault Pod: ${VAULT_POD}"

# Get Vault token
VAULT_TOKEN=$(kubectl exec -n vault ${VAULT_POD} -- cat /vault/data/init.txt 2>/dev/null | grep "Initial Root Token:" | awk '{print $NF}')

if [ -z "$VAULT_TOKEN" ]; then
  echo "❌ Could not get Vault token"
  exit 1
fi

echo "Token: ${VAULT_TOKEN:0:10}..."
echo ""

# Login to Vault
echo "Step 1: Logging into Vault..."
kubectl exec -n vault ${VAULT_POD} -- vault login ${VAULT_TOKEN} >/dev/null 2>&1
echo "✅ Logged in"
echo ""

# Get PostgreSQL details
echo "Step 2: Getting PostgreSQL connection details..."
POSTGRES_SERVICE="postgres.tax-calculator.svc.cluster.local"
POSTGRES_PORT="5432"
POSTGRES_DB="taxcalculator"
POSTGRES_USER="taxcalc_user"
POSTGRES_PASSWORD="TaxCalc2024SecurePassword"

echo "PostgreSQL: ${POSTGRES_SERVICE}:${POSTGRES_PORT}"
echo "Database: ${POSTGRES_DB}"
echo "User: ${POSTGRES_USER}"
echo ""

# Enable database secrets engine (if not already enabled)
echo "Step 3: Enabling database secrets engine..."
kubectl exec -n vault ${VAULT_POD} -- vault secrets enable database 2>/dev/null || echo "⚠️  Already enabled"
echo ""

# Configure database connection
echo "Step 4: Configuring database connection..."
kubectl exec -n vault ${VAULT_POD} -- vault write database/config/taxcalculator \
  plugin_name=postgresql-database-plugin \
  allowed_roles="tax-calculator-role" \
  connection_url="postgresql://{{username}}:{{password}}@${POSTGRES_SERVICE}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=disable" \
  username="${POSTGRES_USER}" \
  password="${POSTGRES_PASSWORD}"

echo "✅ Database connection configured"
echo ""

# Create database role
echo "Step 5: Creating database role..."
kubectl exec -n vault ${VAULT_POD} -- vault write database/roles/tax-calculator-role \
  db_name=taxcalculator \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

echo "✅ Role created"
echo ""

# Test credential generation
echo "Step 6: Testing credential generation..."
kubectl exec -n vault ${VAULT_POD} -- vault read database/creds/tax-calculator-role

echo ""
echo "=== Configuration Complete ==="
echo ""

# Restart backend
echo "Restarting backend to use new credentials..."
kubectl rollout restart deployment backend -n tax-calculator

echo "Waiting for backend to restart..."
sleep 45

BACKEND_POD=$(kubectl get pods -n tax-calculator -l component=backend -o jsonpath='{.items[0].metadata.name}')
echo "Backend Pod: ${BACKEND_POD}"

echo ""
echo "Testing backend health:"
kubectl exec -n tax-calculator ${BACKEND_POD} -- curl -s http://localhost:8080/health 2>/dev/null | jq

echo ""
echo "✅ Done! Check backend logs:"
echo "kubectl logs ${BACKEND_POD} -n tax-calculator --tail=30"
