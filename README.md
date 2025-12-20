# Vault GitOps Platform - UK Tax Calculator Demo

> **Production-grade HashiCorp Vault integration with full DevOps stack**  
> Demonstrating dynamic secrets, transit encryption, and GitOps deployment patterns

[![Terraform](https://img.shields.io/badge/Terraform-1.0+-purple?logo=terraform)](https://www.terraform.io/)
[![Vault](https://img.shields.io/badge/Vault-1.14+-black?logo=vault)](https://www.vaultproject.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.27+-blue?logo=kubernetes)](https://kubernetes.io/)
[![ArgoCD](https://img.shields.io/badge/ArgoCD-2.8+-orange?logo=argo)](https://argoproj.github.io/cd/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue?logo=docker)](https://docs.docker.com/compose/)

## 🎯 Overview

This project showcases **enterprise-grade secrets management** and **GitOps deployment patterns** through a real-world UK tax calculator application. It demonstrates the complete DevOps lifecycle from local development to production deployment.

**Built for**: HMRC Senior DevOps Engineer Interview (January 2025)

### Key Features

- ✅ **HashiCorp Vault** - 4 secret engines (dynamic DB, transit encryption, K8s auth, KV)
- ✅ **Infrastructure as Code** - Terraform modules for AWS EKS
- ✅ **GitOps Deployment** - ArgoCD for continuous delivery
- ✅ **Multi-Environment** - Docker Compose (local) + EKS (production)
- ✅ **Zero-Trust Security** - Dynamic credentials, encryption at rest, pod identity

---

## 🚀 Quick Start

### Local Development (2 minutes)

```bash
cd tax-calculator-app
docker-compose up --build
open http://localhost:3000
```

**Perfect for**: Demo, testing, interview presentation

### Cloud Deployment (30 minutes)

```bash
cd terraform/environments/dev
terraform init
terraform apply
# App auto-deploys via ArgoCD
```

**Perfect for**: Production, scalability demonstration

---

## 📋 What's Included

### Application Stack
- **Backend**: Go REST API with UK tax calculations (2024/2025 rates)
- **Frontend**: React UI with government-style design
- **Database**: PostgreSQL with Vault dynamic credentials
- **Secrets**: HashiCorp Vault with comprehensive integration

### Infrastructure
- **Compute**: AWS EKS (Kubernetes)
- **Networking**: VPC with public/private subnets
- **Security**: AWS KMS, IAM roles, security groups
- **GitOps**: ArgoCD for declarative deployments
- **Monitoring**: CloudWatch (ready for Prometheus/Grafana)

### Vault Secret Engines

| Engine | Purpose | Implementation |
|--------|---------|----------------|
| **Database** | Dynamic PostgreSQL credentials | Auto-rotating, 1-hour TTL |
| **Transit** | Encrypt/decrypt PII data | NI number encryption |
| **Kubernetes** | Pod authentication | Service account JWT |
| **KV v2** | Application config | Versioned secrets |

---

## 📁 Repository Structure

```
.
├── README.md                      # This file
├── QUICK_START.md                 # Fast setup guide
├── PROJECT-SUMMARY.md             # Architecture decisions
│
├── tax-calculator-app/            # Application Code
│   ├── docker-compose.yml         # Local environment
│   ├── backend/                   # Go API
│   │   ├── main.go               # Tax calculation logic
│   │   └── vault.go              # Vault integration
│   ├── frontend/                  # React UI
│   │   └── src/App.js            # Main application
│   ├── database/                  # PostgreSQL setup
│   │   └── init.sql              # Schema & sample data
│   └── scripts/                   # Testing utilities
│
├── terraform/                     # Infrastructure as Code
│   ├── environments/
│   │   ├── dev/                  # Development environment
│   │   └── dev-lite/             # Minimal dev setup
│   └── modules/
│       ├── eks/                  # Kubernetes cluster
│       ├── vpc/                  # Network infrastructure
│       ├── vault/                # Vault Helm deployment
│       └── kms/                  # Encryption keys
│
├── gitops/                        # GitOps Configuration
│   ├── applications/             # Application definitions
│   │   └── demo-app/            # Tax calculator app
│   └── infrastructure/           # Infrastructure apps
│       ├── argocd/              # ArgoCD setup
│       └── vault/               # Vault policies
│
├── scripts/                       # Automation
│   ├── setup.sh                  # Complete deployment
│   ├── vault-init.sh             # Vault configuration
│   └── teardown.sh               # Cleanup
│
└── docs/                          # Documentation
    ├── ARCHITECTURE.md           # System design
    ├── INTERVIEW_PREP.md         # Interview guide
    └── deployment-options.md     # Deployment strategies
```

---

## 🎓 Demonstrated Skills

### DevOps Engineering
- ✅ Infrastructure as Code (Terraform)
- ✅ Container orchestration (Kubernetes/Docker)
- ✅ GitOps methodology (ArgoCD)
- ✅ CI/CD pipeline design
- ✅ Cloud architecture (AWS)

### Security Engineering
- ✅ Secret management (Vault)
- ✅ Zero-trust architecture
- ✅ Dynamic credentials
- ✅ Encryption at rest/transit
- ✅ IAM & RBAC

### Software Engineering
- ✅ Go backend development
- ✅ React frontend development
- ✅ RESTful API design
- ✅ Database design
- ✅ Testing strategies

---

## 🔐 Security Features

### Vault Integration
```
Dynamic Database Credentials
└─ PostgreSQL credentials rotate hourly
└─ No static passwords in code
└─ Automatic lease renewal

Transit Encryption Engine
└─ Encrypt PII before storage
└─ NI numbers encrypted with vault:v1: prefix
└─ Keys managed centrally

Kubernetes Authentication
└─ Pod identity via service accounts
└─ No credentials in container images
└─ JWT-based authentication

KV Secrets Engine v2
└─ Versioned configuration
└─ Rollback capability
└─ Audit logging enabled
```

### AWS Security
- VPC with private/public subnets
- Security groups with least privilege
- IAM roles for pod identity (IRSA)
- KMS encryption for Vault storage
- Network policies for pod communication

---

## 🎤 Interview Demo Script

### 5-Minute Demo Flow

**1. Local Setup (30 seconds)**
```bash
cd tax-calculator-app && docker-compose up
```

**2. Show UI (1 minute)**
- Navigate to http://localhost:3000
- Calculate tax for £50,000
- Show encrypted NI number
- Display calculation history

**3. Vault Features (2 minutes)**
- Show Vault UI at http://localhost:8200
- Demonstrate dynamic credentials: `vault read database/creds/tax-calculator-role`
- Show transit encryption: Encrypted NI in database
- Explain Kubernetes auth setup

**4. Architecture Discussion (1.5 minutes)**
- Walk through Terraform modules
- Explain GitOps workflow
- Discuss multi-environment strategy
- Mention HA/DR considerations

**Talking Points**:
- Zero-trust security model
- Infrastructure as Code best practices
- GitOps declarative deployments
- UK government domain expertise (HMRC)

---

## 📊 Deployment Options Comparison

| Feature | Docker Compose | Terraform + EKS |
|---------|----------------|-----------------|
| **Setup Time** | 2 minutes | 30 minutes |
| **Cost** | Free | ~$0.30/hour |
| **Scalability** | Single host | Auto-scaling |
| **Availability** | Single point of failure | Multi-AZ HA |
| **Monitoring** | Basic logs | Full observability |
| **Use Case** | Development, Demo | Production |
| **Best For** | Interview, Testing | Real deployments |

---

## 🛠️ Technology Stack

**Infrastructure**
- Terraform 1.0+
- AWS EKS 1.27+
- HashiCorp Vault 1.14+
- ArgoCD 2.8+

**Application**
- Go 1.21 (Backend)
- React 18 (Frontend)
- PostgreSQL 15
- Docker & Docker Compose

**Tools**
- kubectl
- helm
- vault CLI
- aws CLI

---

## 📚 Documentation

### Getting Started
- [QUICK_START.md](QUICK_START.md) - 2-minute setup
- [docs/getting-started.md](docs/getting-started.md) - Comprehensive guide
- [docs/deployment-options.md](docs/deployment-options.md) - Choose your path

### Application
- [tax-calculator-app/README.md](tax-calculator-app/README.md) - App overview
- [tax-calculator-app/DEMO_SCRIPT.md](tax-calculator-app/DEMO_SCRIPT.md) - Interview demo
- [tax-calculator-app/DOCKER_COMPOSE_GUIDE.md](tax-calculator-app/DOCKER_COMPOSE_GUIDE.md) - Local setup

### Infrastructure
- [PROJECT-SUMMARY.md](PROJECT-SUMMARY.md) - Architecture decisions
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - System design
- [docs/INTERVIEW_PREP.md](docs/INTERVIEW_PREP.md) - Interview guide

---

## 🎯 For HMRC Interview

**Position**: Senior DevOps Engineer  
**Date**: January 8, 2025  
**Organization**: Her Majesty's Revenue and Customs

### Why This Project?

1. **Relevant Domain** - Tax calculation (HMRC's core business)
2. **Enterprise Patterns** - Production-grade infrastructure
3. **Modern Stack** - Current best practices (GitOps, Vault, K8s)
4. **Security Focus** - Government-grade security requirements
5. **Scalability** - Ready for production deployment

### Key Talking Points

- **Zero-trust security** with Vault dynamic credentials
- **GitOps** for declarative, auditable deployments
- **Infrastructure as Code** for reproducible environments
- **Multi-environment** strategy (dev, staging, prod)
- **UK government domain** expertise

---

## 🚧 Future Enhancements

- [ ] Multi-region deployment
- [ ] Service mesh (Istio)
- [ ] Prometheus/Grafana monitoring
- [ ] External Secrets Operator
- [ ] Policy as Code (OPA)
- [ ] Advanced RBAC with Vault policies
- [ ] Automated testing in CI/CD

---

## 📄 License

This project is for demonstration and interview purposes.

---

## 🤝 Contact

Built by **Tobi Akinlade**  
Senior DevOps Engineer | MSc Advanced Computer Science | UK STEM Ambassador

- GitHub: [Your GitHub]
- LinkedIn: [Your LinkedIn]
- Email: [Your Email]

---

**⭐ If this helped you, please star the repository!**

---

Built with ❤️ for the HMRC interview | Showcasing enterprise DevOps excellence
