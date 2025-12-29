#!/bin/bash
set -e

# Part 2 Repository Setup Script
# This script restructures your repository for GitOps

echo "🚀 Setting up Part 2 repository structure..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -d ".git" ]; then
    echo "❌ Error: Not in a git repository. Please run from vault-gitops-platform root."
    exit 1
fi

echo "${YELLOW}Creating directory structure...${NC}"

# Create main directories
mkdir -p applications/tax-calculator/{backend,frontend,database}
mkdir -p kubernetes/{base,overlays/dev,overlays/prod}

# Create Kubernetes base directories
mkdir -p kubernetes/base/tax-calculator/{backend,frontend,database}
mkdir -p kubernetes/base/observability/{prometheus,grafana,loki,alertmanager}
mkdir -p kubernetes/base/logging/{elasticsearch,fluentd,kibana}
mkdir -p kubernetes/base/security/{network-policies,cert-manager,pod-security,falco}
mkdir -p kubernetes/base/operations/{velero,autoscaling,argocd}

# Create ArgoCD directory
mkdir -p argocd/applications

# Create dashboards directory
mkdir -p dashboards/{application,infrastructure,slo,security}

# Create runbooks directory
mkdir -p runbooks/{incidents,maintenance,disaster-recovery}

# Create docs directory
mkdir -p docs/{architecture,operations,security,troubleshooting}

# Create scripts directory
mkdir -p scripts

echo "${GREEN}✅ Directory structure created${NC}"

# Move existing application code
if [ -d "tax-calculator-app" ]; then
    echo "${YELLOW}Moving application code...${NC}"
    
    if [ -d "tax-calculator-app/backend" ]; then
        cp -r tax-calculator-app/backend applications/tax-calculator/
        echo "  ✅ Backend moved"
    fi
    
    if [ -d "tax-calculator-app/frontend" ]; then
        cp -r tax-calculator-app/frontend applications/tax-calculator/
        echo "  ✅ Frontend moved"
    fi
    
    if [ -d "tax-calculator-app/k8s" ]; then
        cp -r tax-calculator-app/k8s applications/tax-calculator/database/
        echo "  ✅ Database manifests copied"
    fi
fi

# Create README files
cat > kubernetes/README.md << 'EOF'
# Kubernetes Manifests

GitOps-ready Kubernetes manifests organized with Kustomize.

## Structure

- `base/`: Base configurations (environment-agnostic)
- `overlays/`: Environment-specific configurations (dev, prod)

## Usage

```bash
# Preview dev environment
kubectl kustomize kubernetes/overlays/dev

# Apply dev environment
kubectl apply -k kubernetes/overlays/dev
```

## ArgoCD

ArgoCD applications reference these manifests from `/argocd/applications/`.
EOF

cat > argocd/README.md << 'EOF'
# ArgoCD Applications

ArgoCD Application manifests for automated deployment.

## Applications

- `tax-calculator.yaml`: Main application
- `observability.yaml`: Prometheus, Grafana, Loki
- `logging.yaml`: ELK stack
- `security.yaml`: Network policies, TLS, PSS
- `operations.yaml`: Velero, autoscaling

## Deployment

```bash
# Deploy ArgoCD application definitions
kubectl apply -f argocd/applications/
```
EOF

cat > applications/README.md << 'EOF'
# Applications

Application source code and Docker configurations.

## Structure

- `tax-calculator/`: UK Tax Calculator application
  - `backend/`: Go API
  - `frontend/`: React UI
  - `database/`: PostgreSQL configurations
EOF

cat > dashboards/README.md << 'EOF'
# Grafana Dashboards

Pre-configured Grafana dashboards as ConfigMaps.

## Categories

- `application/`: Application-specific metrics
- `infrastructure/`: Kubernetes and node metrics
- `slo/`: SLI/SLO tracking
- `security/`: Security events and compliance
EOF

cat > runbooks/README.md << 'EOF'
# Operational Runbooks

Step-by-step procedures for operations and incidents.

## Categories

- `incidents/`: Incident response procedures
- `maintenance/`: Routine maintenance tasks
- `disaster-recovery/`: DR procedures and tests
EOF

cat > scripts/README.md << 'EOF'
# Helper Scripts

Automation scripts for deployment and operations.

## Scripts

- `setup-repository.sh`: Repository structure setup
- `deploy-argocd.sh`: Install ArgoCD
- `deploy-monitoring.sh`: Deploy observability stack
- `deploy-logging.sh`: Deploy ELK stack
- `validate-part2.sh`: Validation script
EOF

echo "${GREEN}✅ README files created${NC}"

# Create .gitignore additions
cat >> .gitignore << 'EOF'

# Part 2 additions
*.log
.DS_Store
.env
secrets/
*.secret
EOF

echo "${GREEN}✅ Updated .gitignore${NC}"

# Git operations
echo "${YELLOW}Committing changes...${NC}"
git add .
git commit -m "feat: Restructure repository for Part 2 - GitOps ready

- Create kubernetes/ directory with base and overlays
- Add argocd/ for application definitions
- Add dashboards/ for Grafana dashboards
- Add runbooks/ for operational procedures
- Add scripts/ for automation
- Migrate application code to applications/
"

echo "${GREEN}✅ Repository restructured successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Push changes: git push origin main"
echo "2. Review structure: tree -L 3"
echo "3. Continue with Day 2 (ArgoCD installation)"
