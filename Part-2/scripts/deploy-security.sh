#!/bin/bash
set -e

# Security Deployment Script
# Network Policies, cert-manager, Pod Security Standards

echo "🔒 Deploying Security Components..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${YELLOW}Step 1: Deploy Network Policies${NC}"

# Default deny all traffic
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: tax-calculator
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: tax-calculator
spec:
  podSelector:
    matchLabels:
      component: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              component: frontend
      ports:
        - protocol: TCP
          port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-postgres
  namespace: tax-calculator
spec:
  podSelector:
    matchLabels:
      component: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              component: backend
      ports:
        - protocol: TCP
          port: 5432
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-vault
  namespace: tax-calculator
spec:
  podSelector:
    matchLabels:
      component: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: vault
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vault
      ports:
        - protocol: TCP
          port: 8200
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internet-to-frontend
  namespace: tax-calculator
spec:
  podSelector:
    matchLabels:
      component: frontend
  policyTypes:
    - Ingress
  ingress:
    - ports:
        - protocol: TCP
          port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scraping
  namespace: tax-calculator
spec:
  podSelector:
    matchLabels:
      app: tax-calculator
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
      ports:
        - protocol: TCP
          port: 8080
EOF

echo "${GREEN}✅ Network Policies deployed${NC}"

echo "${YELLOW}Step 2: Deploy cert-manager${NC}"

# Add cert-manager Helm repo
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.2 \
  --set installCRDs=true \
  --set global.leaderElection.namespace=cert-manager \
  --set prometheus.enabled=true \
  --set prometheus.servicemonitor.enabled=true \
  --set prometheus.servicemonitor.labels.release=kube-prometheus-stack

echo "${BLUE}Waiting for cert-manager to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

echo "${GREEN}✅ cert-manager deployed${NC}"

echo "${YELLOW}Step 3: Create ClusterIssuer for Let's Encrypt${NC}"

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # UPDATE THIS!
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
      - http01:
          ingress:
            class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # UPDATE THIS!
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

echo "${GREEN}✅ ClusterIssuers created${NC}"

echo "${YELLOW}Step 4: Deploy Falco (Runtime Security)${NC}"

helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm upgrade --install falco falcosecurity/falco \
  --namespace security \
  --create-namespace \
  --version 3.8.0 \
  --values - <<EOF
driver:
  kind: modern_ebpf

falco:
  rules_file:
    - /etc/falco/falco_rules.yaml
    - /etc/falco/falco_rules.local.yaml
    - /etc/falco/rules.d
  
  json_output: true
  json_include_output_property: true
  
  priority: warning
  
  # Custom rules
  rules_files:
    - /etc/falco/custom_rules.yaml

falcoctl:
  artifact:
    install:
      enabled: true
    follow:
      enabled: true

customRules:
  custom_rules.yaml: |-
    - rule: Unauthorized Process
      desc: Detect unauthorized processes in containers
      condition: >
        spawned_process and container and
        not proc.name in (known_binaries) and
        not proc.pname in (known_binaries)
      output: >
        Unauthorized process started (user=%user.name command=%proc.cmdline
        container=%container.name image=%container.image.repository)
      priority: WARNING
      tags: [container, process]
    
    - rule: Write below etc
      desc: Detect writes to /etc directory
      condition: >
        write and container and fd.name startswith /etc
      output: >
        File write below /etc (user=%user.name command=%proc.cmdline
        file=%fd.name container=%container.name)
      priority: WARNING
      tags: [filesystem, container]
    
    - rule: Kubernetes Secret Access
      desc: Detect access to Kubernetes secrets
      condition: >
        open_read and container and
        fd.name startswith "/var/run/secrets/kubernetes.io"
      output: >
        Secret accessed (user=%user.name command=%proc.cmdline
        file=%fd.name container=%container.name)
      priority: WARNING
      tags: [kubernetes, secrets]

tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane

resources:
  requests:
    cpu: 100m
    memory: 512Mi
  limits:
    cpu: 200m
    memory: 1Gi

# Service Monitor for Prometheus
serviceMonitor:
  enabled: true
  labels:
    release: kube-prometheus-stack
EOF

echo "${BLUE}Waiting for Falco to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=falco -n security --timeout=300s

echo "${GREEN}✅ Falco deployed${NC}"

echo "${YELLOW}Step 5: Apply Pod Security Standards${NC}"

# Apply Pod Security Standards to namespaces
kubectl label namespace tax-calculator \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

kubectl label namespace monitoring \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

kubectl label namespace logging \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite

echo "${GREEN}✅ Pod Security Standards applied${NC}"

echo ""
echo "${GREEN}=== Security Components Deployed Successfully! ===${NC}"
echo ""
echo "Network Policies:"
echo "  ✓ Default deny all traffic"
echo "  ✓ Frontend → Backend allowed"
echo "  ✓ Backend → PostgreSQL allowed"
echo "  ✓ Backend → Vault allowed"
echo "  ✓ Prometheus scraping allowed"
echo ""
echo "cert-manager:"
echo "  ✓ Installed with CRDs"
echo "  ✓ Let's Encrypt ClusterIssuers created"
echo "  ✓ Prometheus monitoring enabled"
echo ""
echo "Falco:"
echo "  ✓ Runtime security monitoring"
echo "  ✓ Custom security rules"
echo "  ✓ Prometheus metrics enabled"
echo ""
echo "Pod Security:"
echo "  ✓ Restricted mode enforced"
echo "  ✓ Applied to application namespaces"
echo ""
echo "Next steps:"
echo "1. Update ClusterIssuer email addresses"
echo "2. Review Falco alerts in Prometheus/Grafana"
echo "3. Test network policies"
echo "4. Configure TLS certificates for ingress"
