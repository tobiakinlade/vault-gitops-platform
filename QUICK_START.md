# Quick Start Guide

Get the tax calculator running in under 2 minutes.

## 🚀 Local Development (Docker Compose)

```bash
# 1. Clone repository
git clone https://github.com/yourusername/vault-gitops-platform.git
cd vault-gitops-platform

# 2. Start application
cd tax-calculator-app
docker-compose up --build

# 3. Access application
open http://localhost:3000
```

**That's it!** The application is running with full Vault integration.

### Test It
1. Enter income: `50000`
2. Enter NI number: `AB123456C`
3. Click "Calculate Tax"
4. See results with encrypted data!

### Vault UI
- URL: http://localhost:8200
- Token: `root`

### API Health Check
```bash
curl http://localhost:8080/health
```

---

## ☁️ Cloud Deployment (AWS EKS)

### Prerequisites
- AWS account with credentials configured
- Terraform 1.0+
- kubectl
- helm

### Deploy

```bash
# 1. Navigate to environment
cd terraform/environments/dev

# 2. Initialize Terraform
terraform init

# 3. Review plan
terraform plan

# 4. Deploy infrastructure
terraform apply

# 5. Configure kubectl
aws eks update-kubeconfig --name tax-calculator-dev --region eu-west-2

# 6. Verify deployment
kubectl get pods -n tax-calculator
```

Application auto-deploys via ArgoCD.

---

## 🎯 For Interview Demo

**Use Docker Compose** - faster, easier to demonstrate:

```bash
cd tax-calculator-app
docker-compose up
# Ready in 2 minutes!
```

**Discuss EKS deployment** - show infrastructure knowledge without live deployment overhead.

---

## 📚 Next Steps

- Read [README.md](README.md) for full overview
- Check [DEMO_SCRIPT.md](tax-calculator-app/DEMO_SCRIPT.md) for interview guide
- Review [ARCHITECTURE.md](docs/ARCHITECTURE.md) for system design

---

**Good luck with your interview!** 🎉
