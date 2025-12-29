#!/bin/bash
set -e

# ArgoCD Installation and Configuration Script
# Day 2-3: GitOps with ArgoCD

echo "🚀 Installing ArgoCD..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ARGOCD_VERSION="v2.9.3"
GITHUB_REPO="https://github.com/YOUR_USERNAME/vault-gitops-platform.git"  # UPDATE THIS!

echo "${YELLOW}Step 1: Create ArgoCD namespace${NC}"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

echo "${YELLOW}Step 2: Install ArgoCD${NC}"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

echo "${BLUE}Waiting for ArgoCD to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo "${YELLOW}Step 3: Expose ArgoCD Server${NC}"
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "${BLUE}Waiting for LoadBalancer...${NC}"
sleep 30

# Get ArgoCD URL
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "${GREEN}ArgoCD Server:${NC} https://${ARGOCD_SERVER}"

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "${GREEN}Admin Password:${NC} ${ARGOCD_PASSWORD}"

# Save credentials
cat > argocd-credentials.txt << EOF
ArgoCD Access Information
========================
URL: https://${ARGOCD_SERVER}
Username: admin
Password: ${ARGOCD_PASSWORD}

Save this file securely and delete after first login!
EOF

echo "${GREEN}✅ Credentials saved to: argocd-credentials.txt${NC}"

echo "${YELLOW}Step 4: Login with ArgoCD CLI${NC}"
argocd login ${ARGOCD_SERVER} --username admin --password ${ARGOCD_PASSWORD} --insecure

echo "${YELLOW}Step 5: Add Git repository${NC}"
argocd repo add ${GITHUB_REPO} --insecure-ignore-host-key

echo "${YELLOW}Step 6: Configure ArgoCD settings${NC}"
# Enable auto-sync by default
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data": {"application.sync.interval": "3m"}}'

# Configure resource tracking
kubectl patch configmap argocd-cm -n argocd --type merge -p '{
  "data": {
    "resource.customizations": "networking.k8s.io/NetworkPolicy:\n  health.lua: |\n    hs = {}\n    hs.status = \"Healthy\"\n    hs.message = \"NetworkPolicy is healthy\"\n    return hs\n",
    "resource.compareoptions": "ignoreAggregatedRoles: true\nignoreDifferences:\n  - kind: Secret\n    jsonPointers:\n      - /data\n"
  }
}'

# Restart ArgoCD server to apply changes
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd

echo "${GREEN}✅ ArgoCD installed and configured!${NC}"
echo ""
echo "Next steps:"
echo "1. Access ArgoCD UI: https://${ARGOCD_SERVER}"
echo "2. Login with credentials from argocd-credentials.txt"
echo "3. Change admin password (recommended)"
echo "4. Deploy applications: kubectl apply -f argocd/applications/"
echo ""
echo "Port-forward (alternative to LoadBalancer):"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
