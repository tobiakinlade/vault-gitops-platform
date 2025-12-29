# Production-Grade Kubernetes Platform: Part 2 - Complete DevOps Automation

## From GitOps to CI/CD, Observability to SRE - Building Enterprise-Ready Infrastructure

---

## Introduction

In Part 1, we built a production-ready UK Tax Calculator application on AWS EKS with HashiCorp Vault for secrets management. We established a solid foundation with a 3-node Kubernetes cluster, PostgreSQL database, and a secure application stack.

In Part 2, we'll transform this foundation into a complete, enterprise-grade DevOps platform. We'll implement automation, observability, security, and reliability practices that meet production standards.

### What You'll Build

By the end of this comprehensive guide, you'll have:

1. **Complete GitOps Automation** - ArgoCD for declarative, Git-driven deployments
2. **CI/CD Pipeline with Security Gates** - Automated builds, quality checks, and security scanning
3. **Full Observability Stack** - Prometheus, Grafana, and Loki for metrics and logs
4. **Enterprise Logging (Optional)** - ELK stack for advanced log analytics
5. **Security Hardening** - Network policies, TLS automation, and runtime security
6. **Operational Excellence** - Automated backup, disaster recovery, and autoscaling
7. **SRE Practices** - SLI/SLO tracking, error budgets, and reliability dashboards

### The Complete Flow

```
Developer commits code
        ↓
GitHub Actions (CI/CD)
        ↓
Code Quality Check (SonarQube)
        ↓
Security Scan (Trivy)
        ↓
Build & Push Image (ECR)
        ↓
Update Manifest (Git)
        ↓
ArgoCD Auto-Sync
        ↓
Kubernetes Deployment
        ↓
Production Ready!

Timeline: 13 minutes from commit to production
```

---

## Table of Contents

**Part 1: Foundation Setup**
- Namespace organization

**Part 2: GitOps with ArgoCD**
- ArgoCD deployment
- Repository configuration
- Application setup

**Part 3: CI/CD Pipeline**
- SonarQube for code quality
- GitHub Actions workflows
- Trivy security scanning
- Automated deployments

**Part 4: Observability Stack**
- Prometheus metrics
- Grafana dashboards
- Loki log aggregation

**Part 5: Enterprise Logging (Optional)**
- Elasticsearch cluster
- Kibana interface
- Fluentd collection

**Part 6: Security Hardening**
- Network policies
- cert-manager for TLS
- Falco runtime security

**Part 7: Operational Excellence**
- Horizontal Pod Autoscaler
- Velero backup & DR
- Vertical Pod Autoscaler
- Cluster Autoscaler

**Part 8: SRE Practices**
- SLI/SLO framework
- Error budgets
- Burn rate alerts
- Reliability dashboards

**Part 9: Validation & Testing**
- Comprehensive validation
- End-to-end testing

**Part 10: Cost Analysis & Optimization**

---

## Prerequisites

Before starting, ensure you have:

### Required
- ✅ Part 1 deployed and running (3-node EKS cluster with tax calculator application)
- ✅ kubectl installed and configured
- ✅ helm v3 installed
- ✅ AWS CLI configured
- ✅ GitHub account with a repository
- ✅ Basic knowledge of Kubernetes, Docker, and CI/CD

### Verify Your Environment

```bash
# Check cluster connection
kubectl cluster-info
kubectl get nodes
# Expected: 3 nodes in Ready state

# Check Part 1 application
kubectl get pods -n tax-calculator
# Expected: backend, frontend, postgres pods running

# Verify tools
helm version      # Should be v3.x
aws --version     # Should be v2.x
git --version     # Should be v2.x

# Test AWS credentials
aws sts get-caller-identity

# Check GitHub CLI (optional but helpful)
gh --version
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Developer Workflow                       │
│              Git Commit → CI/CD → Production                 │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline Layer                      │
│                                                              │
│  GitHub Actions → SonarQube → Trivy → ECR → ArgoCD         │
│  (Orchestration)  (Quality)   (Security) (Registry) (Deploy)│
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────────┐
│                   GitOps Layer (ArgoCD)                      │
│                 Watches Git → Syncs to Cluster               │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────────┐
│                  Application Layer                           │
│                                                              │
│  Frontend (React) ←→ Backend (Go) ←→ PostgreSQL             │
│                          ↓                                   │
│                    Vault (Secrets)                           │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────────┐
│               Observability Layer                            │
│                                                              │
│  Prometheus  │  Grafana   │  Loki/ELK  │  AlertManager     │
│  (Metrics)   │ (Dashboards)│  (Logs)   │  (Alerts)         │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────────┐
│                   Security Layer                             │
│                                                              │
│  Network Policies  │  cert-manager  │  Falco               │
│  (Zero Trust)      │  (TLS Auto)    │  (Runtime)           │
└─────────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────────┐
│                  Operations Layer                            │
│                                                              │
│  Velero  │  HPA  │  VPA  │  Cluster Autoscaler             │
│  (Backup)│ (Auto)│ (Auto)│  (Nodes)                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Part 1: Foundation Setup

### Step 1: Create Namespace Structure

We'll organize our cluster with dedicated namespaces for different operational domains.

```bash
# Create namespace configuration
cat > namespaces.yaml <<'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
    app.kubernetes.io/part-of: gitops
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
    app.kubernetes.io/part-of: observability
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: logging
  labels:
    name: logging
    app.kubernetes.io/part-of: observability
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: elastic-system
  labels:
    name: elastic-system
    app.kubernetes.io/part-of: logging
---
apiVersion: v1
kind: Namespace
metadata:
  name: security
  labels:
    name: security
    app.kubernetes.io/part-of: security
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
  labels:
    name: cert-manager
    app.kubernetes.io/part-of: security
---
apiVersion: v1
kind: Namespace
metadata:
  name: velero
  labels:
    name: velero
    app.kubernetes.io/part-of: operations
---
apiVersion: v1
kind: Namespace
metadata:
  name: sonarqube
  labels:
    name: sonarqube
    app.kubernetes.io/part-of: cicd
EOF

# Apply namespaces
kubectl apply -f namespaces.yaml

# Verify creation
kubectl get namespaces
```

**Expected Output:**
```
NAME              STATUS   AGE
argocd            Active   5s
cert-manager      Active   5s
elastic-system    Active   5s
logging           Active   5s
monitoring        Active   5s
security          Active   5s
sonarqube         Active   5s
tax-calculator    Active   2d
vault             Active   2d
velero            Active   5s
```

---

## Part 2: GitOps with ArgoCD

GitOps transforms Git into the single source of truth for your infrastructure. ArgoCD continuously monitors your repository and automatically synchronizes changes to your cluster.

### Why GitOps?

- **Declarative:** Describe desired state in Git
- **Versioned:** Complete audit trail of all changes
- **Automated:** No manual kubectl commands
- **Recoverable:** Easy rollback with git revert
- **Auditable:** Every change is tracked

### Step 2: Install ArgoCD

```bash
# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.9.3/manifests/install.yaml

# Wait for pods to be ready (this takes 2-3 minutes)
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Check deployment
kubectl get pods -n argocd
```

**Expected Output:**
```
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-application-controller-0       1/1     Running   0          2m
argocd-applicationset-controller-xxx  1/1     Running   0          2m
argocd-dex-server-xxx                 1/1     Running   0          2m
argocd-notifications-controller-xxx   1/1     Running   0          2m
argocd-redis-xxx                      1/1     Running   0          2m
argocd-repo-server-xxx                1/1     Running   0          2m
argocd-server-xxx                     1/1     Running   0          2m
```

### Step 3: Expose ArgoCD UI

```bash
# Patch ArgoCD server service to LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Wait for LoadBalancer to be provisioned
echo "Waiting for LoadBalancer..."
sleep 60

# Get ArgoCD URL
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ArgoCD URL: https://${ARGOCD_SERVER}"

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Save credentials
cat > argocd-credentials.txt <<EOF
ArgoCD Access Information
========================
URL: https://${ARGOCD_SERVER}
Username: admin
Password: ${ARGOCD_PASSWORD}

IMPORTANT: Save this file securely and change the password after first login!
EOF

echo "✓ ArgoCD credentials saved to argocd-credentials.txt"
cat argocd-credentials.txt
```

**Alternative Access (Port Forward):**
```bash
# If LoadBalancer is not available
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# Username: admin
# Password: (from argocd-credentials.txt)
```

### Step 4: Install ArgoCD CLI (Optional but Recommended)

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Verify installation
argocd version --client
```

### Step 5: Login to ArgoCD

```bash
# Login via CLI
argocd login ${ARGOCD_SERVER} \
  --username admin \
  --password ${ARGOCD_PASSWORD} \
  --insecure

# Change default password (recommended)
argocd account update-password
```

### Step 6: Connect Your Git Repository

```bash
# Add your repository (update YOUR_USERNAME)
argocd repo add https://github.com/YOUR_USERNAME/vault-gitops-platform.git \
  --name vault-gitops-platform \
  --type git

# Verify repository connection
argocd repo list

# Expected output:
# TYPE  NAME                      REPO                                                           INSECURE  OCI    LFS    CREDS  STATUS      MESSAGE
# git   vault-gitops-platform     https://github.com/YOUR_USERNAME/vault-gitops-platform.git     false     false  false  false  Successful
```

**Validation:**
- ✅ ArgoCD UI is accessible
- ✅ Can login with admin credentials
- ✅ Repository connected successfully
- ✅ ArgoCD CLI working

---

## Part 3: CI/CD Pipeline with Security Scanning

Now we'll build a complete CI/CD pipeline with automated testing, code quality checks, and security scanning. Every commit will flow through multiple gates before reaching production.

### Pipeline Architecture

```
1. Code Commit (Git push)
        ↓
2. GitHub Actions Trigger
        ↓
3. SonarQube Code Analysis
   - Test coverage check (>80%)
   - Code quality scan
   - Security vulnerabilities (SAST)
        ↓ (Quality Gate)
4. Docker Image Build
        ↓
5. Trivy Security Scan
   - OS vulnerabilities
   - Dependency issues
   - CRITICAL/HIGH blocking
        ↓ (Security Gate)
6. Push to ECR
        ↓
7. Update K8s Manifest
        ↓
8. Commit Manifest Change
        ↓
9. ArgoCD Detects Change
        ↓
10. ArgoCD Syncs to Cluster
        ↓
11. Application Deployed!

Total Time: ~13 minutes
```

### Step 7: Deploy SonarQube

SonarQube provides continuous code quality inspection and security analysis (SAST).

```bash
# Add SonarQube Helm repository
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update

# Create SonarQube values file
cat > sonarqube-values.yaml <<'EOF'
replicaCount: 1

# PostgreSQL for SonarQube
postgresql:
  enabled: true
  postgresqlPassword: "sonarpass"
  persistence:
    enabled: true
    storageClass: gp3
    size: 20Gi

# SonarQube persistence
persistence:
  enabled: true
  storageClass: gp3
  size: 10Gi

# Service configuration
service:
  type: LoadBalancer
  port: 9000

# Resource limits
resources:
  requests:
    cpu: 500m
    memory: 2Gi
  limits:
    cpu: 2000m
    memory: 4Gi

# Security context
initContainers:
  securityContext:
    privileged: true

# Plugins
plugins:
  install:
    - https://github.com/dependency-check/dependency-check-sonar-plugin/releases/download/3.0.1/sonar-dependency-check-plugin-3.0.1.jar

# JVM options
env:
  - name: SONAR_WEB_JAVAADDITIONALOPTS
    value: "-javaagent:/opt/sonarqube/lib/common/sonar-instrumentations-bootstrap.jar"
EOF

# Install SonarQube
echo "Installing SonarQube (this takes 5-10 minutes)..."
helm upgrade --install sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  --values sonarqube-values.yaml \
  --version 10.2.0 \
  --wait \
  --timeout 10m

# Wait for SonarQube to be fully ready
kubectl wait --for=condition=ready pod -l app=sonarqube -n sonarqube --timeout=600s

# Verify deployment
kubectl get pods -n sonarqube
kubectl get svc sonarqube-sonarqube -n sonarqube
```

### Step 8: Access and Configure SonarQube

```bash
# Get SonarQube URL
SONARQUBE_URL=$(kubectl get svc sonarqube-sonarqube -n sonarqube -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "SonarQube URL: http://${SONARQUBE_URL}:9000"

# Or use port-forward
kubectl port-forward svc/sonarqube-sonarqube -n sonarqube 9000:9000
# Access at: http://localhost:9000
```

**In SonarQube UI (http://localhost:9000):**

1. **First Login:**
   - Username: `admin`
   - Password: `admin`
   - You'll be prompted to change the password

2. **Generate Token for GitHub Actions:**
   - Click on your profile (top right)
   - My Account → Security → Generate Token
   - Token Name: `github-actions`
   - Type: `User Token`
   - Click Generate
   - **COPY AND SAVE THIS TOKEN** (you'll need it for GitHub Secrets)

3. **Create Backend Project:**
   - Click "Create Project" → "Manually"
   - Project key: `tax-calculator-backend`
   - Display name: `Tax Calculator Backend`
   - Click "Set Up"

4. **Create Frontend Project:**
   - Click "Create Project" → "Manually"
   - Project key: `tax-calculator-frontend`
   - Display name: `Tax Calculator Frontend`
   - Click "Set Up"

5. **Configure Quality Gate:**
   - Go to Quality Gates
   - Click "Create"
   - Name: `Production Quality Gate`
   - Add Conditions:
     - Coverage: Minimum 80%
     - Duplicated Lines: Maximum 3%
     - Maintainability Rating: A
     - Reliability Rating: A
     - Security Rating: A
   - Set as Default

### Step 9: Prepare GitHub Repository

Ensure your repository has this structure:

```bash
vault-gitops-platform/
├── .github/
│   └── workflows/
│       ├── backend-ci.yml       # We'll create this
│       ├── frontend-ci.yml      # We'll create this
│       └── security-scan.yml    # We'll create this
├── tax-calculator-app/
│   ├── backend/
│   │   ├── Dockerfile          # We'll update this
│   │   ├── go.mod
│   │   ├── main.go
│   │   └── sonar-project.properties  # We'll create this
│   └── frontend/
│       ├── Dockerfile          # We'll update this
│       ├── package.json
│       └── sonar-project.properties  # We'll create this
├── kubernetes/
│   └── base/
│       └── tax-calculator/
│           ├── backend/
│           │   ├── deployment.yaml
│           │   └── service.yaml
│           └── frontend/
│               ├── deployment.yaml
│               └── service.yaml
└── argocd/
    └── applications/
        ├── tax-calculator-backend.yaml   # We'll create this
        └── tax-calculator-frontend.yaml  # We'll create this
```

### Step 10: Setup GitHub Secrets

In your GitHub repository:

1. Go to **Settings → Secrets and variables → Actions → New repository secret**

2. Add these secrets:

```
Name: AWS_ACCESS_KEY_ID
Value: [Your AWS Access Key]

Name: AWS_SECRET_ACCESS_KEY
Value: [Your AWS Secret Key]

Name: AWS_REGION
Value: eu-west-2

Name: ECR_REGISTRY
Value: [Your AWS Account ID].dkr.ecr.eu-west-2.amazonaws.com

Name: SONAR_HOST_URL
Value: http://[SonarQube LoadBalancer URL]:9000

Name: SONAR_TOKEN
Value: [Token generated in Step 8]

Name: ARGOCD_SERVER
Value: [ArgoCD LoadBalancer URL]

Name: ARGOCD_AUTH_TOKEN
Value: [Generate this in next step]
```

### Step 11: Generate ArgoCD Token for GitHub Actions

```bash
# Create service account for GitHub Actions
kubectl create serviceaccount github-actions -n argocd

# Create role with necessary permissions
cat > argocd-github-actions-role.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: github-actions
  namespace: argocd
rules:
  - apiGroups: ["argoproj.io"]
    resources: ["applications"]
    verbs: ["get", "list", "update", "sync", "patch"]
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: github-actions
  namespace: argocd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: github-actions
subjects:
  - kind: ServiceAccount
    name: github-actions
    namespace: argocd
EOF

kubectl apply -f argocd-github-actions-role.yaml

# Generate token for the service account
ARGOCD_TOKEN=$(kubectl create token github-actions -n argocd --duration=87600h)
echo "ArgoCD Token for GitHub Actions:"
echo "${ARGOCD_TOKEN}"
echo ""
echo "Add this as ARGOCD_AUTH_TOKEN in GitHub Secrets"
```

### Step 12: Create ECR Repositories

```bash
# Create ECR repositories for backend and frontend
aws ecr create-repository \
  --repository-name tax-calculator-backend \
  --region eu-west-2

aws ecr create-repository \
  --repository-name tax-calculator-frontend \
  --region eu-west-2

# Verify
aws ecr describe-repositories --region eu-west-2
```

### Step 13: Create Backend Dockerfile (Security-Hardened)

Create or update `tax-calculator-app/backend/Dockerfile`:

```dockerfile
# Multi-stage build for security and minimal image size
FROM golang:1.21-alpine AS builder

# Install security updates and CA certificates
RUN apk update && \
    apk upgrade && \
    apk add --no-cache ca-certificates git tzdata && \
    update-ca-certificates

# Set working directory
WORKDIR /build

# Copy go mod files first (for caching)
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build with security flags
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -a -installsuffix cgo \
    -ldflags="-w -s -X main.version=$(git describe --tags --always --dirty 2>/dev/null || echo 'dev')" \
    -o backend .

# Run tests during build
RUN go test -v ./...

# Final stage - use scratch for minimal attack surface
FROM scratch

# Copy CA certificates from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy binary
COPY --from=builder /build/backend /backend

# Use non-root user
USER 65534:65534

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/backend", "health"] || exit 1

# Run application
ENTRYPOINT ["/backend"]
```

### Step 14: Create SonarQube Configuration for Backend

Create `tax-calculator-app/backend/sonar-project.properties`:

```properties
# Project identification
sonar.projectKey=tax-calculator-backend
sonar.projectName=Tax Calculator Backend
sonar.projectVersion=1.0

# Source code
sonar.sources=.
sonar.exclusions=**/*_test.go,**/vendor/**,**/*.pb.go

# Tests
sonar.tests=.
sonar.test.inclusions=**/*_test.go

# Coverage
sonar.go.coverage.reportPaths=coverage.out
sonar.coverageReportPaths=coverage.out

# Language
sonar.language=go
sonar.sourceEncoding=UTF-8

# Quality Gates
sonar.qualitygate.wait=true
sonar.qualitygate.timeout=300
```

### Step 15: Create Backend CI/CD Workflow

Create `.github/workflows/backend-ci.yml`:

```yaml
name: Backend CI/CD

on:
  push:
    branches: [main, develop]
    paths:
      - 'tax-calculator-app/backend/**'
      - '.github/workflows/backend-ci.yml'
  pull_request:
    branches: [main]
    paths:
      - 'tax-calculator-app/backend/**'

env:
  GO_VERSION: '1.21'
  IMAGE_NAME: tax-calculator-backend
  AWS_REGION: eu-west-2

jobs:
  # Job 1: Code Quality Analysis with SonarQube
  sonarqube-analysis:
    name: SonarQube Code Quality
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for better analysis

      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: ${{ env.GO_VERSION }}

      - name: Cache Go modules
        uses: actions/cache@v3
        with:
          path: ~/go/pkg/mod
          key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
          restore-keys: |
            ${{ runner.os }}-go-

      - name: Install dependencies
        working-directory: ./tax-calculator-app/backend
        run: go mod download

      - name: Run tests with coverage
        working-directory: ./tax-calculator-app/backend
        run: |
          go test -v -coverprofile=coverage.out -covermode=atomic ./...
          go tool cover -func=coverage.out

      - name: SonarQube Scan
        uses: SonarSource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
        with:
          projectBaseDir: ./tax-calculator-app/backend
          args: >
            -Dsonar.projectKey=tax-calculator-backend
            -Dsonar.go.coverage.reportPaths=coverage.out
            -Dsonar.sources=.
            -Dsonar.exclusions=**/*_test.go,**/vendor/**

      - name: Quality Gate Check
        uses: SonarSource/sonarqube-quality-gate-action@master
        timeout-minutes: 5
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}

  # Job 2: Build Docker Image and Security Scan
  build-and-scan:
    name: Build Image & Security Scan
    runs-on: ubuntu-latest
    needs: sonarqube-analysis
    if: github.event_name == 'push'
    
    outputs:
      image-tag: ${{ steps.meta.outputs.version }}
      image-digest: ${{ steps.build.outputs.digest }}
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=sha,prefix={{branch}}-
            type=semver,pattern={{version}}
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build Docker image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: ./tax-calculator-app/backend
          file: ./tax-calculator-app/backend/Dockerfile
          push: false
          load: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            VERSION=${{ steps.meta.outputs.version }}

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'  # Fail build on critical/high vulnerabilities

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Run Trivy for detailed report
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ secrets.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}
          format: 'table'
          severity: 'CRITICAL,HIGH,MEDIUM'

      - name: Push image to Amazon ECR
        if: success()
        id: push
        uses: docker/build-push-action@v5
        with:
          context: ./tax-calculator-app/backend
          file: ./tax-calculator-app/backend/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # Job 3: Update Kubernetes Manifests
  update-manifests:
    name: Update K8s Manifests
    runs-on: ubuntu-latest
    needs: build-and-scan
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Update deployment manifest
        run: |
          IMAGE_TAG="${{ needs.build-and-scan.outputs.image-tag }}"
          echo "Updating backend deployment to use image tag: ${IMAGE_TAG}"
          
          sed -i "s|image:.*backend.*|image: ${{ secrets.ECR_REGISTRY }}/${{ env.IMAGE_NAME }}:${IMAGE_TAG}|g" \
            kubernetes/base/tax-calculator/backend/deployment.yaml
          
          cat kubernetes/base/tax-calculator/backend/deployment.yaml

      - name: Commit and push changes
        run: |
          git config --local user.email "github-actions[bot]@users.noreply.github.com"
          git config --local user.name "github-actions[bot]"
          
          git add kubernetes/base/tax-calculator/backend/deployment.yaml
          
          if git diff --staged --quiet; then
            echo "No changes to commit"
          else
            git commit -m "chore(backend): update image to ${{ needs.build-and-scan.outputs.image-tag }}"
            git push
          fi

  # Job 4: Trigger ArgoCD Sync
  argocd-sync:
    name: Deploy via ArgoCD
    runs-on: ubuntu-latest
    needs: update-manifests
    
    steps:
      - name: Install ArgoCD CLI
        run: |
          curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
          chmod +x argocd
          sudo mv argocd /usr/local/bin/
          argocd version --client

      - name: Sync ArgoCD application
        run: |
          argocd login ${{ secrets.ARGOCD_SERVER }} \
            --auth-token ${{ secrets.ARGOCD_AUTH_TOKEN }} \
            --grpc-web \
            --insecure
          
          echo "Syncing tax-calculator-backend application..."
          argocd app sync tax-calculator-backend --prune
          
          echo "Waiting for application to be healthy..."
          argocd app wait tax-calculator-backend --timeout 300

      - name: Get deployment status
        run: |
          argocd app get tax-calculator-backend
```

### Step 16: Create ArgoCD Application for Backend

Create `argocd/applications/tax-calculator-backend.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: tax-calculator-backend
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: https://github.com/YOUR_USERNAME/vault-gitops-platform.git  # UPDATE THIS
    targetRevision: HEAD
    path: kubernetes/base/tax-calculator/backend
  
  destination:
    server: https://kubernetes.default.svc
    namespace: tax-calculator
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  # Ignore HPA-controlled replica count
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

Apply the ArgoCD application:

```bash
# Update YOUR_USERNAME in the file first
sed -i 's/YOUR_USERNAME/your-github-username/g' argocd/applications/tax-calculator-backend.yaml

# Apply
kubectl apply -f argocd/applications/tax-calculator-backend.yaml

# Verify
argocd app get tax-calculator-backend
```

### Step 17: Test the Complete CI/CD Pipeline

```bash
# Make a test change to trigger the pipeline
cd tax-calculator-app/backend
echo "// CI/CD Pipeline Test - $(date)" >> main.go

# Commit and push
git add .
git commit -m "test: trigger CI/CD pipeline"
git push origin main

echo "Pipeline triggered! Watch progress at:"
echo "1. GitHub Actions: https://github.com/YOUR_USERNAME/vault-gitops-platform/actions"
echo "2. SonarQube: http://localhost:9000"
echo "3. ArgoCD: https://${ARGOCD_SERVER}"
```

**Expected Timeline:**

```
T+0:00 - Code pushed to GitHub
T+0:30 - GitHub Actions starts
T+1:00 - Go tests complete
T+2:00 - SonarQube analysis complete ✓
T+2:30 - Quality gate passes ✓
T+4:00 - Docker build complete
T+5:00 - Trivy scan complete ✓
T+5:30 - Security gate passes ✓
T+7:00 - Image pushed to ECR ✓
T+8:00 - Manifest updated in Git ✓
T+9:00 - ArgoCD detects change ✓
T+10:00 - ArgoCD syncs to cluster ✓
T+12:00 - Pods rolling out
T+13:00 - Deployment complete! ✓
```

**Monitor the Pipeline:**

```bash
# Watch GitHub Actions
gh run watch

# Watch ArgoCD sync
argocd app get tax-calculator-backend --refresh
argocd app wait tax-calculator-backend

# Watch pods rolling out
kubectl get pods -n tax-calculator -w
```

**Validation Checklist:**

- ✅ GitHub Actions workflow completes successfully
- ✅ SonarQube quality gate passes (>80% coverage)
- ✅ Trivy scan passes (no CRITICAL/HIGH vulnerabilities)
- ✅ Image pushed to ECR
- ✅ Manifest updated in repository
- ✅ ArgoCD detects and syncs change
- ✅ New pods deploy successfully
- ✅ Application remains healthy

---

## Part 4: Observability Stack

Complete visibility into your system is crucial for production operations. We'll implement metrics collection, visualization, and log aggregation.

### Why Observability Matters

- **Metrics:** Track system performance and health
- **Logs:** Debug issues and audit activity  
- **Visualization:** Understand system behavior
- **Alerting:** Proactive issue detection

### Step 18: Deploy Prometheus Stack

Prometheus is the de facto standard for Kubernetes monitoring.

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create Prometheus values file
cat > prometheus-values.yaml <<'EOF'
# Prometheus configuration
prometheus:
  prometheusSpec:
    retention: 30d
    retentionSize: "50GB"
    
    # Persistent storage
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          storageClassName: gp3
          resources:
            requests:
              storage: 50Gi
    
    # Resource limits
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi
    
    # Scrape all ServiceMonitors/PodMonitors
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    
    # Additional scrape configs
    additionalScrapeConfigs:
      - job_name: 'kubernetes-pods'
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true

# Grafana configuration
grafana:
  enabled: true
  adminPassword: "admin123"  # CHANGE THIS IN PRODUCTION!
  
  persistence:
    enabled: true
    storageClassName: gp3
    size: 10Gi
  
  service:
    type: LoadBalancer
    port: 80
  
  # Pre-install dashboards
  defaultDashboardsEnabled: true
  
  # Dashboard sidecar
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
      searchNamespace: ALL
    datasources:
      enabled: true
      label: grafana_datasource

# AlertManager configuration
alertmanager:
  enabled: true
  
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          storageClassName: gp3
          resources:
            requests:
              storage: 10Gi
    
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi

# Additional components
kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true
EOF

# Install Prometheus stack (this takes 5-10 minutes)
echo "Installing Prometheus stack..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml \
  --version 55.5.0 \
  --wait \
  --timeout 10m

# Verify deployment
kubectl get pods -n monitoring
```

**Expected Output:**
```
NAME                                                   READY   STATUS    RESTARTS   AGE
alertmanager-kube-prometheus-stack-alertmanager-0      2/2     Running   0          5m
kube-prometheus-stack-grafana-xxx                      3/3     Running   0          5m
kube-prometheus-stack-kube-state-metrics-xxx           1/1     Running   0          5m
kube-prometheus-stack-operator-xxx                     1/1     Running   0          5m
kube-prometheus-stack-prometheus-node-exporter-xxx     1/1     Running   0          5m
kube-prometheus-stack-prometheus-node-exporter-xxx     1/1     Running   0          5m
kube-prometheus-stack-prometheus-node-exporter-xxx     1/1     Running   0          5m
prometheus-kube-prometheus-stack-prometheus-0          2/2     Running   0          5m
```

### Step 19: Access Grafana

```bash
# Get Grafana URL
GRAFANA_URL=$(kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana URL: http://${GRAFANA_URL}"

# Or use port-forward
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

# Access at: http://localhost:3000
# Username: admin
# Password: admin123 (change this!)
```

**In Grafana:**

1. **Change Default Password:**
   - Profile → Change Password

2. **Explore Pre-installed Dashboards:**
   - Dashboards → Browse
   - Look for:
     - Kubernetes / Compute Resources / Cluster
     - Kubernetes / Compute Resources / Namespace
     - Kubernetes / Compute Resources / Node
     - Node Exporter / Nodes

3. **Verify Data Sources:**
   - Configuration → Data Sources
   - Should see Prometheus (default)

### Step 20: Access Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090

# Access at: http://localhost:9090
```

**Test Queries in Prometheus:**

```promql
# Check all targets are up
up

# CPU usage by node
node_cpu_seconds_total

# Pod status
kube_pod_status_phase

# Container memory usage
container_memory_usage_bytes

# API server requests
apiserver_request_total
```

### Step 21: Deploy Loki for Log Aggregation

Loki is a horizontally-scalable, highly-available log aggregation system inspired by Prometheus.

```bash
# Add Grafana Helm repository
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create Loki values file
cat > loki-values.yaml <<'EOF'
loki:
  auth_enabled: false
  
  commonConfig:
    replication_factor: 1
  
  storage:
    type: filesystem
  
  schemaConfig:
    configs:
      - from: 2024-01-01
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h

# Single binary mode for simplicity
singleBinary:
  replicas: 1
  
  persistence:
    enabled: true
    storageClass: gp3
    size: 30Gi
  
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi

# Disable gateway
gateway:
  enabled: false

# Enable ServiceMonitor for Prometheus
monitoring:
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack

# Disable test pod
test:
  enabled: false
EOF

# Install Loki
echo "Installing Loki..."
helm upgrade --install loki grafana/loki \
  --namespace logging \
  --values loki-values.yaml \
  --version 5.41.0 \
  --wait

# Install Promtail (log collector)
cat > promtail-values.yaml <<'EOF'
config:
  clients:
    - url: http://loki-gateway.logging.svc.cluster.local/loki/api/v1/push

daemonset:
  enabled: true

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

# ServiceMonitor for Prometheus
serviceMonitor:
  enabled: true
  labels:
    release: kube-prometheus-stack
EOF

echo "Installing Promtail..."
helm upgrade --install promtail grafana/promtail \
  --namespace logging \
  --values promtail-values.yaml \
  --version 6.15.3 \
  --wait

# Verify deployment
kubectl get pods -n logging
```

### Step 22: Configure Loki in Grafana

The Loki data source should be automatically configured. Verify:

1. **In Grafana:** Configuration → Data Sources
2. **Look for:** Loki
3. **If not present, add manually:**
   - Name: Loki
   - Type: Loki
   - URL: `http://loki-gateway.logging.svc.cluster.local`

### Step 23: Test Log Collection

```bash
# Generate some logs
kubectl run test-logger --image=busybox --restart=Never -- sh -c "while true; do echo 'Test log entry at $(date)'; sleep 1; done"

# Wait a minute, then check in Grafana
```

**In Grafana:**

1. Go to **Explore** (compass icon)
2. Select **Loki** data source
3. Use query: `{namespace="tax-calculator"}`
4. Click **Run query**
5. You should see logs from backend, frontend, and postgres pods

**Test Queries:**

```logql
# All logs from tax-calculator namespace
{namespace="tax-calculator"}

# Backend logs only
{namespace="tax-calculator", pod=~"backend-.*"}

# Error logs
{namespace="tax-calculator"} |= "error"

# JSON logs parsed
{namespace="tax-calculator"} | json

# Rate of logs
rate({namespace="tax-calculator"}[5m])
```

**Validation:**
- ✅ Prometheus collecting metrics from all nodes
- ✅ Grafana dashboards showing data
- ✅ Loki aggregating logs from all pods
- ✅ Can query logs by namespace/pod
- ✅ AlertManager ready for alert rules

---

*[Continue with remaining parts: Enterprise Logging, Security, Operations, SRE, Validation, Cost Analysis]*

**Note:** The tutorial continues with the remaining sections. Would you like me to continue with the complete remaining sections, or would you prefer the document up to this point first?

---

## Summary of What's Completed So Far

✅ **Part 1:** Foundation (Namespaces)
✅ **Part 2:** GitOps (ArgoCD)
✅ **Part 3:** CI/CD Pipeline (SonarQube, GitHub Actions, Trivy)
✅ **Part 4:** Observability (Prometheus, Grafana, Loki) - COMPLETED

### Remaining Sections

⏳ **Part 5:** Enterprise Logging (ELK Stack - Optional)
⏳ **Part 6:** Security Hardening
⏳ **Part 7:** Operational Excellence
⏳ **Part 8:** SRE Practices
⏳ **Part 9:** Validation & Testing
⏳ **Part 10:** Cost Analysis

**Would you like me to continue with the complete remaining sections?**

---

## Part 5: Enterprise Logging with ELK Stack (Optional)

**Note:** This section is optional and adds approximately $135/month to infrastructure costs. Skip if budget is a concern - Loki provides sufficient logging for most use cases.

The ELK (Elasticsearch, Logstash, Kibana) stack provides advanced log analytics, longer retention, and enterprise features.

### When to Use ELK

- Compliance requirements (90+ day retention)
- Multiple teams need access
- Advanced search and analytics
- Security investigations
- Large-scale logging (10GB+/day)

### Step 24: Deploy Elasticsearch

```bash
# Add Elastic Helm repository
helm repo add elastic https://helm.elastic.co
helm repo update

# Create Elasticsearch values
cat > elasticsearch-values.yaml <<'EOF'
clusterName: "elasticsearch"
replicas: 3

# Node resources
resources:
  requests:
    cpu: "500m"
    memory: "2Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

# Persistent storage
volumeClaimTemplate:
  accessModes: ["ReadWriteOnce"]
  storageClassName: gp3
  resources:
    requests:
      storage: 30Gi

# JVM heap size
esJavaOpts: "-Xmx1g -Xms1g"

# Anti-affinity for HA
antiAffinity: "soft"

# Disable security for simplicity (enable in production!)
esConfig:
  elasticsearch.yml: |
    xpack.security.enabled: false
    xpack.security.http.ssl.enabled: false
    xpack.security.transport.ssl.enabled: false
EOF

# Install Elasticsearch (takes 10-15 minutes)
echo "Installing Elasticsearch (this will take 10-15 minutes)..."
helm upgrade --install elasticsearch elastic/elasticsearch \
  --namespace elastic-system \
  --values elasticsearch-values.yaml \
  --version 8.5.1 \
  --wait \
  --timeout 15m

# Monitor the deployment
kubectl get pods -n elastic-system -w
# Wait until all 3 elasticsearch-master pods are Running
# Press Ctrl+C when ready
```

### Step 25: Deploy Kibana

```bash
# Create Kibana values
cat > kibana-values.yaml <<'EOF'
elasticsearchHosts: "http://elasticsearch-master:9200"

resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1000m"
    memory: "2Gi"

service:
  type: LoadBalancer
  port: 5601

kibanaConfig:
  kibana.yml: |
    server.host: "0.0.0.0"
    elasticsearch.hosts: ["http://elasticsearch-master:9200"]
EOF

# Install Kibana
helm upgrade --install kibana elastic/kibana \
  --namespace elastic-system \
  --values kibana-values.yaml \
  --version 8.5.1 \
  --wait

# Get Kibana URL
KIBANA_URL=$(kubectl get svc kibana-kibana -n elastic-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Kibana URL: http://${KIBANA_URL}:5601"
```

### Step 26: Deploy Fluentd

```bash
# Create Fluentd ConfigMap
cat > fluentd-config.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: elastic-system
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      read_from_head true
      <parse>
        @type json
        time_format %Y-%m-%dT%H:%M:%S.%NZ
      </parse>
    </source>

    <filter kubernetes.**>
      @type kubernetes_metadata
      @id filter_kube_metadata
    </filter>

    <match **>
      @type elasticsearch
      host elasticsearch-master
      port 9200
      logstash_format true
      logstash_prefix kubernetes
      <buffer>
        @type file
        path /var/log/fluentd-buffers/kubernetes.system.buffer
        flush_mode interval
        flush_interval 5s
        chunk_limit_size 2M
        queue_limit_length 8
        overflow_action block
      </buffer>
    </match>
EOF

kubectl apply -f fluentd-config.yaml

# Create Fluentd DaemonSet
cat > fluentd-daemonset.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: elastic-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd
rules:
  - apiGroups: [""]
    resources: ["pods", "namespaces"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: fluentd
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: fluentd
    namespace: elastic-system
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: elastic-system
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      serviceAccountName: fluentd
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      containers:
        - name: fluentd
          image: fluent/fluentd-kubernetes-daemonset:v1-debian-elasticsearch
          env:
            - name: FLUENT_ELASTICSEARCH_HOST
              value: "elasticsearch-master"
            - name: FLUENT_ELASTICSEARCH_PORT
              value: "9200"
            - name: FLUENT_ELASTICSEARCH_SCHEME
              value: "http"
            - name: FLUENT_UID
              value: "0"
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: config
              mountPath: /fluentd/etc/fluent.conf
              subPath: fluent.conf
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
        - name: config
          configMap:
            name: fluentd-config
EOF

kubectl apply -f fluentd-daemonset.yaml

# Verify Fluentd is running on all nodes
kubectl get pods -n elastic-system -l app=fluentd
```

### Step 27: Configure Kibana

```bash
# Port-forward Kibana
kubectl port-forward svc/kibana-kibana -n elastic-system 5601:5601
# Access at: http://localhost:5601
```

**In Kibana UI:**

1. **Create Index Pattern:**
   - Go to Management → Stack Management → Index Patterns
   - Click "Create index pattern"
   - Index pattern name: `kubernetes-*`
   - Time field: `@timestamp`
   - Click "Create index pattern"

2. **Explore Logs:**
   - Go to Analytics → Discover
   - Select time range: Last 1 hour
   - You should see logs from all pods

3. **Create Filters:**
   - Filter by namespace: `kubernetes.namespace_name: "tax-calculator"`
   - Filter by pod: `kubernetes.pod_name: "backend-*"`

**Test Elasticsearch:**

```bash
# Check cluster health
ES_POD=$(kubectl get pods -n elastic-system -l app=elasticsearch-master -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n elastic-system $ES_POD -- curl -s http://localhost:9200/_cluster/health | jq

# Expected: "status": "green" or "yellow"

# Check indices
kubectl exec -n elastic-system $ES_POD -- curl -s http://localhost:9200/_cat/indices?v
```

**Validation:**
- ✅ 3 Elasticsearch pods running
- ✅ Kibana accessible
- ✅ Fluentd running on all nodes
- ✅ Logs appearing in Kibana
- ✅ Can search and filter logs

---

## Part 6: Security Hardening

Security must be built into the platform from day one. We'll implement multiple layers of defense.

### Step 28: Implement Network Policies

Network policies control traffic between pods, implementing zero-trust networking.

```bash
# Create network policies for tax-calculator namespace
cat > network-policies.yaml <<'EOF'
# Default deny all ingress and egress
---
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

# Allow frontend to backend
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

# Allow backend to database
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

# Allow backend egress to Vault and DNS
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-egress
  namespace: tax-calculator
spec:
  podSelector:
    matchLabels:
      component: backend
  policyTypes:
    - Egress
  egress:
    # Allow to Vault
    - to:
        - namespaceSelector:
            matchLabels:
              name: vault
      ports:
        - protocol: TCP
          port: 8200
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
        - podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
    # Allow to postgres
    - ports:
        - protocol: TCP
          port: 5432

# Allow internet to frontend
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

# Allow Prometheus to scrape metrics
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scraping
  namespace: tax-calculator
spec:
  podSelector: {}
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
        - protocol: TCP
          port: 9090
EOF

# Apply network policies
kubectl apply -f network-policies.yaml

# Verify
kubectl get networkpolicies -n tax-calculator
```

### Step 29: Test Network Policies

```bash
# Test 1: Application should still work
FRONTEND_URL=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -X POST "http://${FRONTEND_URL}/api/v1/calculate" \
  -H "Content-Type: application/json" \
  -d '{"income": 50000, "national_insurance": "AB123456C", "tax_year": "2024/2025"}'
# Expected: Successful response

# Test 2: Unauthorized access should be blocked
kubectl run test-pod --image=busybox --rm -it --restart=Never -- \
  wget -O- http://backend.tax-calculator.svc.cluster.local:8080 --timeout=5
# Expected: Connection timeout (this is correct!)
```

### Step 30: Deploy cert-manager

cert-manager automates TLS certificate management.

```bash
# Add Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.13.2 \
  --set installCRDs=true \
  --set prometheus.enabled=true \
  --set prometheus.servicemonitor.enabled=true \
  --set prometheus.servicemonitor.labels.release=kube-prometheus-stack \
  --wait

# Verify
kubectl get pods -n cert-manager
```

### Step 31: Create ClusterIssuers

```bash
# Create ClusterIssuers for Let's Encrypt
cat > cluster-issuers.yaml <<'EOF'
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # UPDATE THIS
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
    email: your-email@example.com  # UPDATE THIS
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

# Apply
kubectl apply -f cluster-issuers.yaml

# Verify
kubectl get clusterissuers
```

### Step 32: Deploy Falco for Runtime Security

Falco monitors runtime behavior and detects suspicious activities.

```bash
# Add Falco Helm repository
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Create Falco values
cat > falco-values.yaml <<'EOF'
driver:
  kind: modern_ebpf

falco:
  json_output: true
  json_include_output_property: true
  priority: warning
  
  rules_file:
    - /etc/falco/falco_rules.yaml
    - /etc/falco/falco_rules.local.yaml
    - /etc/falco/rules.d

customRules:
  rules-custom.yaml: |-
    - rule: Unexpected Process Spawned
      desc: Detect unexpected process in container
      condition: >
        spawned_process and container and
        not proc.name in (node, java, python, sh, bash, nginx, postgres)
      output: >
        Unexpected process spawned (user=%user.name command=%proc.cmdline
        container=%container.name image=%container.image.repository)
      priority: WARNING

tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master

resources:
  requests:
    cpu: 100m
    memory: 512Mi
  limits:
    cpu: 200m
    memory: 1Gi

serviceMonitor:
  enabled: true
  labels:
    release: kube-prometheus-stack
EOF

# Install Falco
helm upgrade --install falco falcosecurity/falco \
  --namespace security \
  --values falco-values.yaml \
  --version 3.8.0 \
  --wait

# Verify Falco is running on all nodes
kubectl get pods -n security -l app.kubernetes.io/name=falco
```

### Step 33: Monitor Security Events

```bash
# View Falco events
kubectl logs -n security -l app.kubernetes.io/name=falco --tail=50 -f

# You'll see security events like:
# - Shell spawned in container
# - Sensitive file opened
# - Unexpected network connections
```

**Validation:**
- ✅ Network policies active
- ✅ Application still functional
- ✅ Unauthorized access blocked
- ✅ cert-manager deployed
- ✅ Falco monitoring all nodes

---

## Part 7: Operational Excellence

### Step 34: Deploy Horizontal Pod Autoscaler (HPA)

```bash
# Create HPA for backend
cat > backend-hpa.yaml <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: tax-calculator
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 30
        - type: Pods
          value: 2
          periodSeconds: 30
      selectPolicy: Max
EOF

kubectl apply -f backend-hpa.yaml

# Verify
kubectl get hpa -n tax-calculator
```

### Step 35: Test Autoscaling

```bash
# Generate load
for i in {1..1000}; do
  curl -s -X POST "http://${FRONTEND_URL}/api/v1/calculate" \
    -H "Content-Type: application/json" \
    -d '{"income": 50000, "national_insurance": "AB123456C", "tax_year": "2024/2025"}' > /dev/null &
done

# Watch scaling
kubectl get hpa -n tax-calculator -w
kubectl get pods -n tax-calculator -w
```

### Step 36: Deploy Velero for Backup

```bash
# Create S3 bucket
BACKUP_BUCKET="tax-calculator-velero-backups-$(date +%s)"
aws s3 mb s3://${BACKUP_BUCKET} --region eu-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ${BACKUP_BUCKET} \
  --versioning-configuration Status=Enabled

# Create IAM policy
cat > velero-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": "arn:aws:s3:::${BACKUP_BUCKET}/*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::${BACKUP_BUCKET}"
        }
    ]
}
EOF

# Create policy
POLICY_ARN=$(aws iam create-policy \
  --policy-name VeleroBackupPolicy \
  --policy-document file://velero-policy.json \
  --query 'Policy.Arn' \
  --output text)

# Create service account with IRSA
eksctl create iamserviceaccount \
  --cluster=tax-calculator-dev-cluster \
  --name=velero \
  --namespace=velero \
  --attach-policy-arn=${POLICY_ARN} \
  --approve \
  --region=eu-west-2

# Install Velero
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

helm upgrade --install velero vmware-tanzu/velero \
  --namespace velero \
  --version 5.1.0 \
  --set configuration.provider=aws \
  --set configuration.backupStorageLocation.bucket=${BACKUP_BUCKET} \
  --set configuration.backupStorageLocation.config.region=eu-west-2 \
  --set configuration.volumeSnapshotLocation.config.region=eu-west-2 \
  --set credentials.useSecret=false \
  --set serviceAccount.server.create=false \
  --set serviceAccount.server.name=velero \
  --set initContainers[0].name=velero-plugin-for-aws \
  --set initContainers[0].image=velero/velero-plugin-for-aws:v1.8.0 \
  --set initContainers[0].volumeMounts[0].mountPath=/target \
  --set initContainers[0].volumeMounts[0].name=plugins \
  --wait
```

### Step 37: Create Backup Schedules

```bash
# Install Velero CLI
# macOS: brew install velero
# Linux: Download from https://velero.io/docs/main/basic-install/

# Create daily backup schedule
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --include-namespaces tax-calculator,vault \
  --ttl 720h

# Create weekly full backup
velero schedule create weekly-full-backup \
  --schedule="0 3 * * 0" \
  --include-namespaces "*" \
  --ttl 2160h

# Test manual backup
velero backup create manual-test \
  --include-namespaces tax-calculator \
  --wait

# Check backup
velero backup describe manual-test
velero backup logs manual-test
```

**Validation:**
- ✅ HPA scaling working
- ✅ Velero running
- ✅ Backup successful
- ✅ Backups in S3

---

## Part 8: SRE Practices

### Step 38: Implement SLI/SLO Framework

```bash
# Create PrometheusRules for SLIs and SLOs
cat > sli-slo-rules.yaml <<'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tax-calculator-slis
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: tax-calculator.slis
      interval: 30s
      rules:
        # Availability SLI
        - record: sli:availability:ratio_rate5m
          expr: |
            sum(rate(http_requests_total{namespace="tax-calculator",component="backend",status!~"5.."}[5m]))
            /
            sum(rate(http_requests_total{namespace="tax-calculator",component="backend"}[5m]))
        
        # Latency SLI (p95)
        - record: sli:latency:p95
          expr: |
            histogram_quantile(0.95,
              sum(rate(http_request_duration_seconds_bucket{namespace="tax-calculator",component="backend"}[5m]))
              by (le)
            )
        
        # Error Rate SLI
        - record: sli:errors:ratio_rate5m
          expr: |
            sum(rate(http_requests_total{namespace="tax-calculator",component="backend",status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total{namespace="tax-calculator",component="backend"}[5m]))

    - name: tax-calculator.slos
      interval: 1m
      rules:
        # Availability SLO: 99.9%
        - record: slo:availability:target
          expr: 0.999
        
        # Latency SLO: p95 < 200ms
        - record: slo:latency:target_p95
          expr: 0.200
        
        # Monthly error budget
        - record: slo:error_budget:monthly
          expr: |
            (1 - slo:availability:target) * 30 * 24 * 60 * 60

    - name: tax-calculator.burn_rate
      interval: 1m
      rules:
        # Fast burn rate (1 hour)
        - record: slo:burn_rate:1h
          expr: |
            (
              1 - (
                sum(rate(http_requests_total{namespace="tax-calculator",component="backend",status!~"5.."}[1h]))
                /
                sum(rate(http_requests_total{namespace="tax-calculator",component="backend"}[1h]))
              )
            )
            /
            (1 - slo:availability:target)
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tax-calculator-alerts
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: tax-calculator.alerts
      interval: 1m
      rules:
        - alert: HighErrorBudgetBurnRate
          expr: slo:burn_rate:1h > 14.4
          for: 5m
          labels:
            severity: critical
            component: backend
          annotations:
            summary: "High error budget burn rate"
            description: "Error budget burning at {{ $value }}x normal rate"
        
        - alert: SLOAvailabilityBreach
          expr: sli:availability:ratio_rate5m < slo:availability:target
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Availability SLO breached"
            description: "Current availability {{ $value | humanizePercentage }} below target"
        
        - alert: LatencySLOApproaching
          expr: sli:latency:p95 > (slo:latency:target_p95 * 0.9)
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Latency approaching SLO"
            description: "P95 latency {{ $value }}s approaching target"
EOF

kubectl apply -f sli-slo-rules.yaml
```

### Step 39: Create SLO Dashboard

```bash
# This dashboard will be imported into Grafana
cat > slo-dashboard-configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: tax-calculator-slo-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  slo-dashboard.json: |
    {
      "dashboard": {
        "title": "Tax Calculator - SLO Dashboard",
        "tags": ["slo", "sre", "tax-calculator"],
        "timezone": "UTC",
        "refresh": "30s",
        "panels": [
          {
            "id": 1,
            "title": "Availability SLI vs SLO",
            "type": "graph",
            "targets": [
              {
                "expr": "sli:availability:ratio_rate5m * 100",
                "legendFormat": "Current Availability"
              },
              {
                "expr": "slo:availability:target * 100",
                "legendFormat": "SLO Target (99.9%)"
              }
            ]
          },
          {
            "id": 2,
            "title": "Latency SLI (p95)",
            "type": "graph",
            "targets": [
              {
                "expr": "sli:latency:p95 * 1000",
                "legendFormat": "P95 Latency"
              },
              {
                "expr": "slo:latency:target_p95 * 1000",
                "legendFormat": "Target (200ms)"
              }
            ]
          }
        ]
      }
    }
EOF

kubectl apply -f slo-dashboard-configmap.yaml
```

**Validation:**
- ✅ SLI rules deployed
- ✅ SLO targets defined
- ✅ Burn rate calculated
- ✅ Alerts configured
- ✅ Dashboard created

---

## Part 9: Validation & Testing

### Step 40: Comprehensive Validation

```bash
# Create validation script
cat > validate-part2.sh <<'ENDOFVALIDATION'
#!/bin/bash

echo "==================================="
echo " Part 2 Validation"
echo "==================================="
echo ""

PASSED=0
FAILED=0

check() {
    local name=$1
    local command=$2
    
    echo -n "Checking $name... "
    if eval "$command" &>/dev/null; then
        echo "✓"
        ((PASSED++))
    else
        echo "✗"
        ((FAILED++))
    fi
}

# ArgoCD
check "ArgoCD pods" "kubectl get pods -n argocd | grep -q Running"
check "ArgoCD service" "kubectl get svc argocd-server -n argocd"

# CI/CD
check "SonarQube" "kubectl get pods -n sonarqube | grep -q Running"

# Monitoring
check "Prometheus" "kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus | grep -q Running"
check "Grafana" "kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana | grep -q Running"
check "AlertManager" "kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager | grep -q Running"

# Logging
check "Loki" "kubectl get pods -n logging -l app.kubernetes.io/name=loki | grep -q Running"
check "Promtail" "kubectl get pods -n logging -l app.kubernetes.io/name=promtail | grep -q Running"

# Security
check "cert-manager" "kubectl get pods -n cert-manager | grep -q Running"
check "Falco" "kubectl get pods -n security | grep -q Running"
check "Network policies" "kubectl get networkpolicies -n tax-calculator | grep -q default-deny-all"

# Operations
check "Velero" "kubectl get pods -n velero | grep -q Running"
check "HPA" "kubectl get hpa -n tax-calculator | grep -q backend-hpa"

# SRE
check "SLI rules" "kubectl get prometheusrules -n monitoring | grep -q tax-calculator-slis"
check "SLO alerts" "kubectl get prometheusrules -n monitoring | grep -q tax-calculator-alerts"

echo ""
echo "================================"
echo " Results"
echo "================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ All checks passed!"
    exit 0
else
    echo "✗ Some checks failed"
    exit 1
fi
ENDOFVALIDATION

chmod +x validate-part2.sh
./validate-part2.sh
```

---

## Part 10: Cost Analysis

### Monthly Infrastructure Costs

**Part 1 (Foundation):** $389/month
- EKS Control Plane: $73
- 3× t3.large nodes: $188
- NAT Gateways: $98
- Load Balancers: $22
- EBS volumes: $8

**Part 2 Additions (Lightweight):** +$41/month
- SonarQube (t3.medium): $30
- PostgreSQL storage: $2
- SonarQube storage: $1
- Prometheus storage: $2
- Loki storage: $1
- Velero S3: $5
- ECR storage: $0.50

**Total Lightweight:** $430/month

**Part 2 with ELK (Enterprise):** +$176/month
- Lightweight additions: $41
- Elasticsearch (3× t3.medium): $125
- Elasticsearch storage (90GB): $10

**Total Enterprise:** $565/month

### ROI Analysis

**Time Savings:**
- Manual deployment: 1-2 hours
- Automated pipeline: 13 minutes
- **Savings per deployment:** 1.5+ hours

**Monthly Value (20 deployments):**
- Time saved: 30+ hours
- At $100/hour: $3,000
- Platform cost: $430-565
- **ROI: 5-7x**

---

## Conclusion

You now have a complete, production-grade Kubernetes platform with:

✅ **End-to-end automation** - 13 minutes commit to production
✅ **Code quality gates** - 80%+ coverage enforced
✅ **Security scanning** - Zero critical vulnerabilities
✅ **Complete observability** - Metrics, logs, dashboards
✅ **Security hardening** - Zero-trust networking
✅ **Operational excellence** - Backup, DR, autoscaling
✅ **SRE practices** - SLI/SLO tracking

### Key Achievements

- **40+ pods** across 8 namespaces
- **99.9%+ availability** monitored
- **13-minute deployments** automated
- **Complete audit trail** via GitOps
- **Zero vulnerabilities** in production

### Next Steps

1. Production hardening
2. Advanced deployments
3. Enhanced monitoring
4. Team onboarding

**Complete code:** https://github.com/YOUR_USERNAME/vault-gitops-platform

---

*Part 2 Complete - December 2025*
