#!/bin/bash

# Quick Start Script for Local Tax Calculator Development
# This script sets up everything you need to run locally

set -e

echo "🚀 Tax Calculator - Local Setup"
echo "================================"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker Desktop."
    exit 1
fi

if ! command -v go &> /dev/null; then
    echo "❌ Go not found. Please run: brew install go"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "❌ Node.js not found. Please run: brew install node"
    exit 1
fi

echo "✅ All prerequisites installed!"
echo ""

# Start PostgreSQL
echo "🐘 Starting PostgreSQL..."
docker rm -f postgres-local 2>/dev/null || true
docker run -d \
  --name postgres-local \
  -e POSTGRES_DB=taxcalc \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres123 \
  -p 5432:5432 \
  postgres:15-alpine

echo "⏳ Waiting for PostgreSQL to start..."
sleep 10

# Start Vault
echo "🔐 Starting Vault (dev mode)..."
docker rm -f vault-local 2>/dev/null || true
docker run -d \
  --name vault-local \
  -p 8200:8200 \
  -e VAULT_DEV_ROOT_TOKEN_ID=root \
  -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
  --cap-add=IPC_LOCK \
  hashicorp/vault:latest

echo "⏳ Waiting for Vault to start..."
sleep 5

# Configure Vault
echo "⚙️  Configuring Vault..."
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'

# Enable secrets engines
docker exec vault-local vault secrets enable transit
docker exec vault-local vault write -f transit/keys/tax-calculator

docker exec vault-local vault secrets enable database
docker exec vault-local vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="tax-calculator-role" \
  connection_url="postgresql://{{username}}:{{password}}@host.docker.internal:5432/taxcalc?sslmode=disable" \
  username="postgres" \
  password="postgres123"

docker exec vault-local vault write database/roles/tax-calculator-role \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON DATABASE taxcalc TO \"{{name}}\"; GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

echo "✅ Vault configured!"
echo ""

# Setup environment
echo "📝 Creating environment file..."
cat > backend/.env.local <<EOF
VAULT_ADDR=http://localhost:8200
VAULT_TOKEN=root
DB_HOST=localhost
DB_PORT=5432
DB_NAME=taxcalc
PORT=8080
EOF

echo "✅ Environment configured!"
echo ""

# Install dependencies
echo "📦 Installing Go dependencies..."
cd backend
go mod download
cd ..

echo "📦 Installing Node dependencies..."
cd frontend
npm install --silent
cd ..

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "To start the application:"
echo ""
echo "Terminal 1 (Backend):"
echo "  cd backend"
echo "  source .env.local"
echo "  go run main.go vault.go"
echo ""
echo "Terminal 2 (Frontend):"
echo "  cd frontend"
echo "  npm start"
echo ""
echo "Then open: http://localhost:3000"
echo ""
echo "To stop everything:"
echo "  docker stop postgres-local vault-local"
echo ""
