# 🇬🇧 UK Tax Calculator with HashiCorp Vault

**Production-ready demo application for HMRC Interview - January 8, 2025**

## 🎯 Project Overview

A complete tax calculation microservice demonstrating HashiCorp Vault integration in a government-relevant context. Perfect for demonstrating secure secret management, PII protection, and compliance in a 5-10 minute interview demo.

## ✨ Features

### Application Features
- ✅ UK tax calculation (2024/2025 rates)
- ✅ Income tax and National Insurance computation
- ✅ Calculation history with encrypted PII
- ✅ Real-time results with breakdown
- ✅ Clean, professional UI

### Vault Integration Features
- ✅ **Dynamic Database Credentials** - PostgreSQL credentials from Vault
- ✅ **Transit Encryption** - National Insurance numbers encrypted
- ✅ **Kubernetes Authentication** - Pod-level identity via IRSA
- ✅ **KV Secrets** - API keys and configuration
- ✅ **Audit Logging** - Complete compliance trail
- ✅ **Automatic Credential Rotation** - Hourly rotation

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────┐
│              Tax Calculator Application               │
│                                                       │
│  ┌──────────────┐         ┌──────────────┐          │
│  │   Frontend   │────────→│   Backend    │          │
│  │   (React)    │         │     (Go)     │          │
│  └──────────────┘         └───────┬──────┘          │
│                                    │                  │
│         ┌──────────────────────────┼────────────┐   │
│         ↓                          ↓            ↓   │
│    ┌─────────┐              ┌──────────┐  ┌──────┐ │
│    │  Vault  │              │PostgreSQL│  │Audit │ │
│    │         │              │          │  │ Log  │ │
│    │ Dynamic │              │Encrypted │  └──────┘ │
│    │  Creds  │              │   Data   │           │
│    │         │              └──────────┘           │
│    │ Transit │                                      │
│    │ Encrypt │                                      │
│    └─────────┘                                      │
└──────────────────────────────────────────────────────┘
```

## 📦 Project Structure

```
tax-calculator-demo/
├── backend/                    # Go API service
│   ├── main.go                # Main server with tax logic
│   ├── vault.go               # Vault client integration
│   ├── go.mod                 # Go dependencies
│   └── Dockerfile             # Backend container
├── frontend/                   # React UI
│   ├── src/
│   │   ├── App.js            # Main React component
│   │   ├── App.css           # Styles
│   │   └── index.js          # React entry point
│   ├── package.json          # Node dependencies
│   ├── Dockerfile            # Frontend container
│   └── nginx.conf            # Nginx configuration
├── k8s/                       # Kubernetes manifests
│   └── base/                 # Base configurations
│       ├── backend.yaml      # Backend deployment
│       ├── frontend.yaml     # Frontend deployment
│       ├── postgres.yaml     # PostgreSQL StatefulSet
│       ├── vault-policy.yaml # Vault policies
│       └── configmap.yaml    # Application config
├── gitops/                    # ArgoCD configurations
│   └── application.yaml      # ArgoCD Application
├── docs/                      # Documentation
│   ├── DEMO_SCRIPT.md        # 5-minute demo script
│   ├── INTERVIEW_GUIDE.md    # Interview talking points
│   └── ARCHITECTURE.md       # Technical details
└── scripts/                   # Deployment scripts
    ├── deploy.sh             # Full deployment
    ├── setup-vault.sh        # Configure Vault
    └── cleanup.sh            # Teardown
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster with Vault installed (from Week 1 project)
- kubectl configured
- Docker (for building images)
- (Optional) ArgoCD for GitOps

### Deployment Steps

```bash
# 1. Clone the repository
cd tax-calculator-demo

# 2. Build and push images (or use pre-built)
docker build -t tax-calculator-backend:latest ./backend
docker build -t tax-calculator-frontend:latest ./frontend

# 3. Setup Vault
./scripts/setup-vault.sh

# 4. Deploy to Kubernetes
kubectl apply -k k8s/base/

# 5. Access the application
kubectl port-forward svc/tax-calculator-frontend 3000:80
# Open http://localhost:3000
```

## 🔒 Vault Configuration

### 1. Enable Required Engines

```bash
# Database secrets engine
vault secrets enable database

# Transit encryption engine
vault secrets enable transit

# KV secrets engine (already enabled)
vault secrets enable -path=secret kv-v2
```

### 2. Configure Database Secrets

```bash
# Configure PostgreSQL connection
vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="tax-calculator-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/taxcalc?sslmode=disable" \
  username="postgres" \
  password="<postgres-password>"

# Create role for dynamic credentials
vault write database/roles/tax-calculator-role \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
```

### 3. Configure Transit Encryption

```bash
# Create encryption key
vault write -f transit/keys/tax-calculator

# Configure key rotation
vault write transit/keys/tax-calculator/config \
  min_decryption_version=1 \
  min_encryption_version=1 \
  deletion_allowed=false
```

### 4. Create Policies

```hcl
# tax-calculator-policy.hcl
path "database/creds/tax-calculator-role" {
  capabilities = ["read"]
}

path "transit/encrypt/tax-calculator" {
  capabilities = ["update"]
}

path "transit/decrypt/tax-calculator" {
  capabilities = ["update"]
}

path "secret/data/config/tax-calculator" {
  capabilities = ["read"]
}

vault policy write tax-calculator tax-calculator-policy.hcl
```

### 5. Configure Kubernetes Auth

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create role
vault write auth/kubernetes/role/tax-calculator \
  bound_service_account_names=tax-calculator \
  bound_service_account_namespaces=default \
  policies=tax-calculator \
  ttl=24h
```

## 🎯 Interview Demo Script (5 Minutes)

### Minute 1: Introduction
"This is a tax calculation service that demonstrates how HMRC could securely handle citizen data using HashiCorp Vault. It shows dynamic credentials, PII encryption, and complete audit trails."

### Minute 2-3: Live Demo
1. Open the UI (http://localhost:3000)
2. Enter income: £50,000
3. Enter NI number: AB123456C
4. Click Calculate
5. Show results:
   - Tax breakdown
   - Encrypted NI number
   - Calculation ID

### Minute 4: Technical Walkthrough
```bash
# Show Vault integration
kubectl logs -f <backend-pod> | grep Vault

# Show database credentials rotation
vault read database/creds/tax-calculator-role

# Show encrypted data in database
kubectl exec -it postgres-0 -- psql -d taxcalc -c "SELECT encrypted_ni FROM tax_calculations LIMIT 1;"
```

### Minute 5: Security Highlights
- ✅ Zero static credentials
- ✅ Automatic hourly rotation
- ✅ PII encrypted at rest
- ✅ Complete audit trail
- ✅ Kubernetes-native auth

## 💡 Interview Talking Points

### 1. Why This Architecture?

**Dynamic Credentials:**
> "Instead of hardcoding database passwords, Vault generates short-lived credentials on-demand. This eliminates credential sprawl and reduces blast radius if compromised."

**Transit Encryption:**
> "National Insurance numbers are encrypted using Vault's Transit engine before storage. The encryption keys never leave Vault, and we get centralized key management."

**Kubernetes Auth:**
> "Using Kubernetes service account tokens for authentication means zero secrets in Git or environment variables. The pod's identity IS the authentication."

**Audit Logging:**
> "Every Vault operation is logged. We can prove who accessed what, when, and for what purpose - critical for GDPR and government compliance."

### 2. Government Relevance

**HMRC Context:**
> "This mirrors HMRC's need to:
> - Handle millions of tax calculations
> - Protect National Insurance numbers (PII)
> - Maintain audit trails for compliance
> - Rotate credentials without downtime
> - Scale securely across multiple environments"

### 3. Production Readiness

**High Availability:**
> "In production, we'd run 3+ backend replicas, PostgreSQL with replication, and Vault in HA mode with Raft storage."

**Disaster Recovery:**
> "Vault snapshots every 6 hours, database backups, GitOps for infrastructure recovery. RTO < 30 minutes, RPO < 6 hours."

**Cost Optimization:**
> "Current setup costs £90-110/month on AWS. Production would be £450-550/month for full HA across 3 AZs."

### 4. What I'd Add Next

**Immediate (Week 2):**
- ArgoCD for GitOps deployment
- Prometheus/Grafana for observability
- Automated testing pipeline

**Near-term (Week 3-4):**
- Service mesh (Istio) for mTLS
- OPA for policy enforcement
- Synthetic monitoring

**Long-term:**
- Multi-region deployment
- Vault Performance Replication
- Advanced DR testing

## 🔧 Local Development

### Run Backend Locally

```bash
cd backend

# Set environment variables
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-token>
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=taxcalc
export DB_USER=postgres
export DB_PASSWORD=<password>

# Run
go run main.go vault.go
```

### Run Frontend Locally

```bash
cd frontend

# Install dependencies
npm install

# Start dev server
REACT_APP_API_URL=http://localhost:8080 npm start
```

## 📊 Testing

### Manual Testing

```bash
# Health check
curl http://localhost:8080/health

# Calculate tax
curl -X POST http://localhost:8080/api/v1/calculate \
  -H "Content-Type: application/json" \
  -d '{
    "income": 50000,
    "national_insurance": "AB123456C",
    "tax_year": "2024/2025"
  }'

# Get history
curl http://localhost:8080/api/v1/history
```

### Load Testing

```bash
# Install k6
brew install k6  # macOS
apt install k6   # Linux

# Run load test
k6 run scripts/load-test.js
```

## 🎓 Educational Value

### For Learners

This project teaches:
- Vault integration patterns
- Kubernetes secret management
- Go API development
- React frontend development
- DevOps best practices
- Government compliance patterns

### For Interviews

Demonstrates:
- Production-ready architecture
- Security-first mindset
- Government sector understanding
- Cost optimization awareness
- Practical problem-solving

## 🐛 Troubleshooting

### Backend Can't Connect to Vault

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# Check service account
kubectl get sa tax-calculator

# Check Vault policy
vault policy read tax-calculator
```

### Database Connection Fails

```bash
# Check PostgreSQL
kubectl get pods -l app=postgres

# Test connection
kubectl exec -it postgres-0 -- psql -U postgres -d taxcalc

# Check Vault database config
vault read database/config/postgres
```

### Frontend Can't Reach Backend

```bash
# Check backend service
kubectl get svc tax-calculator-backend

# Check backend logs
kubectl logs -f <backend-pod>

# Test API directly
kubectl port-forward svc/tax-calculator-backend 8080:8080
curl http://localhost:8080/health
```

## 📚 Additional Resources

- [Vault Documentation](https://www.vaultproject.io/docs)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/)
- [HMRC Digital Services](https://www.gov.uk/government/organisations/hm-revenue-customs/services-information)
- [UK Tax Rates 2024/2025](https://www.gov.uk/income-tax-rates)

## 🤝 Contributing

This is a demonstration project for interview purposes. Feel free to fork and adapt for your use case.

## 📝 License

MIT License - See LICENSE file for details

## 👤 Author

**Tobi Akinlade**
- Senior DevOps Engineer
- SC Clearance
- Preparing for HMRC Interview - January 8, 2025

---

**Built to demonstrate production-grade DevOps practices for government sector roles.** 🚀
