#!/bin/bash

# Revised Cleanup Strategy - Keep Infrastructure, Remove Duplicates
# For full stack: Docker Compose + Terraform + EKS + ArgoCD

set -e

echo "🧹 Organizing vault-gitops-platform directory..."
echo "📝 Keeping: Terraform, GitOps, and Application code"
echo ""

# Create backup first
echo "📦 Creating backup..."
mkdir -p .cleanup-backup
cp -r . .cleanup-backup/ 2>/dev/null || true

# Remove duplicate documentation files
echo "🗑️  Removing duplicate documentation..."

# Keep QUICK_START.md, remove QUICKSTART.md
if [ -f "QUICKSTART.md" ] && [ -f "QUICK_START.md" ]; then
    echo "  - Removing duplicate QUICKSTART.md (keeping QUICK_START.md)"
    rm QUICKSTART.md
fi

# Remove duplicate project summaries
if [ -f "PROJECT_SUMMARY.md" ] && [ -f "PROJECT-SUMMARY.md" ]; then
    echo "  - Removing duplicate PROJECT-SUMMARY.md"
    rm PROJECT-SUMMARY.md
fi

# Archive outdated delivery/update summaries
echo "📁 Archiving outdated summary files..."
mkdir -p archive/old-summaries
mv DELIVERY_SUMMARY.md archive/old-summaries/ 2>/dev/null && echo "  - Archived DELIVERY_SUMMARY.md"
mv UPDATE_SUMMARY.md archive/old-summaries/ 2>/dev/null && echo "  - Archived UPDATE_SUMMARY.md"

# Create consolidated README
echo "📝 Creating consolidated README..."
cat > README.md << 'EOF'
# Vault GitOps Platform - HMRC Interview Demo

**Production-grade infrastructure with HashiCorp Vault for UK Tax Calculator**

## 🏗️ Architecture

This project demonstrates enterprise DevOps practices with:

- ✅ **Infrastructure as Code** - Terraform for AWS EKS
- ✅ **GitOps Deployment** - ArgoCD for continuous delivery
- ✅ **Secrets Management** - HashiCorp Vault with 4 secret engines
- ✅ **Containerization** - Docker/Kubernetes
- ✅ **Local Development** - Docker Compose for testing

## 🚀 Deployment Options

### Option 1: Local Development (Docker Compose)
**Fast setup for testing and demo**

```bash
cd tax-calculator-app
docker-compose up --build
open http://localhost:3000
```

**Time**: 2 minutes  
**Use**: Local testing, interview demo  
**Features**: Full Vault integration, database, UI

### Option 2: Cloud Deployment (Terraform + EKS + ArgoCD)
**Production-grade AWS infrastructure**

```bash
cd terraform/environments/dev
terraform init
terraform apply
# Then deploy app with ArgoCD
```

**Time**: 30 minutes  
**Use**: Production deployment  
**Features**: Auto-scaling, HA, GitOps, monitoring

## 📁 Project Structure

```
.
├── README.md                      ← Project overview
├── QUICK_START.md                 ← Quick setup guide
├── PROJECT-SUMMARY.md             ← Architecture & decisions
│
├── tax-calculator-app/            ← Application code
│   ├── docker-compose.yml         ← Local development
│   ├── backend/                   ← Go API
│   ├── frontend/                  ← React UI
│   ├── database/                  ← PostgreSQL
│   ├── scripts/                   ← Test/deploy scripts
│   └── *.md                       ← App documentation
│
├── terraform/                     ← Infrastructure as Code
│   ├── environments/
│   │   ├── dev/                   ← Dev environment
│   │   └── dev-lite/              ← Minimal dev setup
│   └── modules/
│       ├── eks/                   ← EKS cluster
│       ├── vpc/                   ← Network infrastructure
│       ├── vault/                 ← Vault Helm deployment
│       └── kms/                   ← AWS KMS for Vault
│
├── gitops/                        ← GitOps configuration
│   ├── applications/              ← ArgoCD apps
│   │   └── demo-app/
│   └── infrastructure/            ← Infrastructure apps
│       ├── argocd/
│       └── vault/
│
├── scripts/                       ← Automation scripts
│   ├── setup.sh                   ← Complete setup
│   ├── vault-init.sh              ← Vault initialization
│   ├── teardown.sh                ← Cleanup
│   └── cleanup.sh
│
└── docs/                          ← Documentation
    ├── ARCHITECTURE.md
    ├── getting-started.md
    ├── deployment-options.md
    ├── local-development.md
    └── INTERVIEW_PREP.md
```

## 🎯 For HMRC Interview (January 8, 2025)

### Quick Demo Setup
```bash
# Local demo (recommended for interview)
cd tax-calculator-app
docker-compose up
```

### What to Show
1. **Vault Integration** - 4 secret engines working
2. **Dynamic Credentials** - Database creds rotate hourly
3. **Transit Encryption** - PII protection in action
4. **Architecture** - Explain Terraform → EKS → ArgoCD flow

### Talking Points
- ✅ Terraform modules for reusable infrastructure
- ✅ GitOps with ArgoCD for declarative deployments
- ✅ Vault for zero-trust security model
- ✅ Multi-environment support (dev, dev-lite)
- ✅ Kubernetes-native with service mesh ready

## 📚 Key Documentation

### Getting Started
- **QUICK_START.md** - 2-minute local setup
- **docs/getting-started.md** - Complete setup guide
- **docs/deployment-options.md** - Choose your deployment

### Application
- **tax-calculator-app/README.md** - App overview
- **tax-calculator-app/DEMO_SCRIPT.md** - 5-min interview demo
- **tax-calculator-app/DEPLOYMENT_GUIDE.md** - K8s deployment

### Infrastructure
- **PROJECT-SUMMARY.md** - Architecture decisions
- **docs/ARCHITECTURE.md** - System design
- **terraform/environments/dev/README.md** - Terraform guide

### Interview Prep
- **docs/INTERVIEW_PREP.md** - Interview talking points
- **tax-calculator-app/DEMO_SCRIPT.md** - Demo walkthrough

## 🔐 Vault Features Demonstrated

### 1. Dynamic Database Secrets
- Auto-rotating PostgreSQL credentials
- 1-hour TTL with automatic renewal
- Eliminates static credentials

### 2. Transit Encryption Engine
- Encrypt/decrypt PII data (NI numbers)
- Keys managed by Vault
- Compliance ready (GDPR, etc.)

### 3. Kubernetes Auth
- Pod identity-based authentication
- Service account integration
- Zero credentials in pods

### 4. KV Secrets v2
- Versioned application config
- Rollback capability
- Audit trail

## 🛠️ Technologies

**Infrastructure**
- Terraform (IaC)
- AWS EKS (Kubernetes)
- ArgoCD (GitOps)
- HashiCorp Vault

**Application**
- Go (Backend API)
- React (Frontend UI)
- PostgreSQL (Database)
- Docker/Docker Compose

**DevOps**
- GitHub Actions (CI/CD)
- Helm (Package management)
- Prometheus/Grafana (Monitoring)

## ✅ Pre-Interview Checklist

**Local Demo (Recommended)**
- [ ] Docker Compose runs: `cd tax-calculator-app && docker-compose up`
- [ ] UI accessible: http://localhost:3000
- [ ] Vault UI works: http://localhost:8200 (token: `root`)
- [ ] Can calculate tax for £50,000
- [ ] Understand all 4 Vault engines

**Cloud Infrastructure (Optional to Mention)**
- [ ] Can explain Terraform structure
- [ ] Understand EKS architecture
- [ ] Know GitOps workflow with ArgoCD
- [ ] Can discuss HA/DR strategy

**Interview Talking Points**
- [ ] Read docs/INTERVIEW_PREP.md
- [ ] Practice DEMO_SCRIPT.md
- [ ] Understand security model
- [ ] Know UK tax calculation logic

## 📊 Deployment Comparison

| Feature | Docker Compose | Terraform + EKS |
|---------|----------------|-----------------|
| Setup Time | 2 minutes | 30 minutes |
| Cost | Free | ~$0.30/hour |
| Use Case | Testing, Demo | Production |
| Scalability | Single host | Auto-scaling |
| HA | No | Yes |
| Monitoring | Basic | Full observability |
| Best For | Interview demo | Real deployment |

## 🎤 Interview Strategy

**For demonstration**, use Docker Compose:
- Fast startup
- All features work
- Easy to explain
- Can show live

**For discussion**, reference Terraform/EKS:
- Shows production experience
- Demonstrates IaC knowledge
- GitOps understanding
- Cloud architecture skills

## 💼 Position Details

**Role**: Senior DevOps Engineer  
**Organization**: HMRC (Her Majesty's Revenue and Customs)  
**Interview Date**: January 8, 2025  
**Focus**: HashiCorp Vault, Secrets Management, Cloud Infrastructure

## 🚀 Quick Commands

```bash
# Local development
cd tax-calculator-app && docker-compose up

# Deploy to AWS
cd terraform/environments/dev
terraform init && terraform apply

# GitOps deployment
kubectl apply -f gitops/applications/demo-app/

# Vault operations
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'
vault read database/creds/tax-calculator-role

# Testing
cd tax-calculator-app
./scripts/test-docker.sh
```

## 📞 Support

- See docs/ for detailed guides
- Check tax-calculator-app/README.md for app details
- Review INTERVIEW_PREP.md for talking points

---

**Good luck with your HMRC interview!** 🎉

This project demonstrates senior-level DevOps capabilities with production-ready infrastructure and enterprise security patterns.
EOF

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📊 Summary of changes:"
echo "  ✅ Removed duplicate documentation files"
echo "  ✅ Archived outdated summaries"
echo "  ✅ Created comprehensive README.md"
echo "  ✅ Kept all infrastructure code (Terraform, GitOps)"
echo "  ✅ Kept all application code (tax-calculator-app)"
echo "  ✅ Backup created in .cleanup-backup/"
echo ""
echo "📁 Your organized structure:"
echo "  ├── README.md                  ← New comprehensive overview"
echo "  ├── QUICK_START.md"
echo "  ├── PROJECT-SUMMARY.md"
echo "  ├── tax-calculator-app/        ← Application"
echo "  ├── terraform/                 ← Infrastructure (kept!)"
echo "  ├── gitops/                    ← GitOps config (kept!)"
echo "  ├── scripts/                   ← Automation (kept!)"
echo "  ├── docs/                      ← Documentation (kept!)"
echo "  └── archive/                   ← Old summaries"
echo ""
echo "🎯 Ready for both local demo AND cloud deployment!"
echo ""
