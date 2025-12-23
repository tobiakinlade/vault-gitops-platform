Perfect! Let's create a complete deployment workflow from infrastructure to application. Here's the step-by-step process:

🚀 Complete Deployment Workflow

Phase 1: Verify Infrastructure ✅
Step 1: Wait for Terraform to Complete
bashcd terraform/environments/dev
terraform apply --auto-approve

# Wait for completion (~20-25 minutes)
# Should end with: "Apply complete! Resources: XX added, 0 changed, 0 destroyed"
Step 2: Configure kubectl
bash aws eks update-kubeconfig --name Tax-Calculator-dev-cluster --region eu-west-2
Step 3: Verify Infrastructure
bash# Check nodes
kubectl get nodes
# Should show 2-3 nodes Ready

# Check EBS CSI driver
kubectl get pods -n kube-system | grep ebs
# Should show 3+ Running pods

# Check StorageClass
kubectl get storageclass
# Should show gp3 (default)

# Check Vault pods
kubectl get pods -n vault
# Should show vault-0, vault-1 Running

# Check PVCs
kubectl get pvc -n vault
# Should show all Bound

Phase 2: Initialize Vault 🔐
Step 4: Initialize Vault
bashkubectl exec -it vault-0 -n vault -- vault operator init
SAVE THE OUTPUT! You'll get:

5 Unseal Keys
1 Root Token

Step 5: Unseal Vault (Both Pods)
bash# Unseal vault-0 (use any 3 of 5 keys)
kubectl exec -it vault-0 -n vault -- vault operator unseal 4kKrp+DyLQO6UIDgYNivC6R4cs3vyrITq60l9uC6WJ5g
kubectl exec -it vault-0 -n vault -- vault operator unseal R9zmv7Issv9R7VbCroanEs/QHy5RLRyQaeM3jf4EGhEB
kubectl exec -it vault-0 -n vault -- vault operator unseal dmLwkokogrQMxlm5PIa+0kM18spg/XQ/CZ2TZqlDJ+i4

oluwatobiakinlade@MacBookPro dev % kubectl exec -it vault-0 -n vault -- vault operator init
Recovery Key 1: 4kKrp+DyLQO6UIDgYNivC6R4cs3vyrITq60l9uC6WJ5g
Recovery Key 2: R9zmv7Issv9R7VbCroanEs/QHy5RLRyQaeM3jf4EGhEB
Recovery Key 3: dmLwkokogrQMxlm5PIa+0kM18spg/XQ/CZ2TZqlDJ+i4
Recovery Key 4: P385EdF2fJosTAn0Illg9pEKJn9zbcfBiiQYPJQV5WxA
Recovery Key 5: X6/5t4tDvOgAnQ0U21grAehJahDfOhhK7BLKHEBgjiLg

# Unseal vault-1
kubectl exec -it vault-1 -n vault -- vault operator unseal 4kKrp+DyLQO6UIDgYNivC6R4cs3vyrITq60l9uC6WJ5g
kubectl exec -it vault-1 -n vault -- vault operator unseal R9zmv7Issv9R7VbCroanEs/QHy5RLRyQaeM3jf4EGhEB
kubectl exec -it vault-1 -n vault -- vault operator unseal dmLwkokogrQMxlm5PIa+0kM18spg/XQ/CZ2TZqlDJ+i4
Step 6: Login to Vault
bash kubectl exec -it vault-0 -n vault -- vault login <ROOT_TOKEN>
Step 7: Verify Vault Status
bash kubectl exec -it vault-0 -n vault -- vault status
kubectl exec -it vault-0 -n vault -- vault operator generate-root -init
A One-Time-Password has been generated for you and is shown in the OTP field.
You will need this value to decode the resulting root token, so keep it safe.
Nonce         b6c5e42c-eb62-916f-739b-ee61fca5365e
Started       true
Progress      0/3
Complete      false
OTP           8rjA5mw3KuLRBnyeyz9REkNeADv4
OTP Length    28




kubectl exec -it vault-0 -n vault -- vault operator generate-root \
  -nonce=b6c5e42c-eb62-916f-739b-ee61fca5365e

input the keys

kubectl exec -it vault-0 -n vault -- vault operator generate-root \
  -decode=UAQZbwY4MwAhGT4EAD8jAS81SwE1DRlXeAwjfg \
  -otp=8rjA5mw3KuLRBnyeyz9REkNeADv4



oluwatobiakinlade@MacBookPro dev % kubectl exec -it vault-0 -n vault -- vault operator generate-root \
  -decode=UAQZbwY4MwAhGT4EAD8jAS81SwE1DRlXeAwjfg \
  -otp=8rjA5mw3KuLRBnyeyz9REkNeADv4
E1221 13:42:05.254411   90126 websocket.go:296] Unknown stream id 1, discarding message
                                                                                       hvs.3UD3jlrVBQZdVOrSpfW29HUJ

kubectl exec -it vault-0 -n vault -- vault login hvs.3UD3jlrVBQZdVOrSpfW29HUJ
# Should show: Sealed = false

Phase 3: Build & Push Container Images 🐳
Step 8: Create ECR Repositories
# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-west-2"

# Create ECR repositories
aws ecr create-repository \
  --repository-name tax-calculator-backend \
  --region $AWS_REGION

aws ecr create-repository \
  --repository-name tax-calculator-frontend \
  --region $AWS_REGION
Step 9: Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
Step 10: Build and Push Backend
bash cd tax-calculator-app/backend

# Build image
docker build -t tax-calculator-backend:latest .

# Tag for ECR
docker tag tax-calculator-backend:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/tax-calculator-backend:latest

# Push to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/tax-calculator-backend:latest
Step 11: Build and Push Frontend
bashcd ../frontend

# Build image
docker build -t tax-calculator-frontend:latest .

# Tag for ECR
docker tag tax-calculator-frontend:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/tax-calculator-frontend:latest

# Push to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/tax-calculator-frontend:latest

Phase 4: Configure Vault Secret Engines 🔑
Step 12: Enable Secret Engines
bash# Enable database secrets engine
kubectl exec -it vault-0 -n vault -- vault secrets enable database

# Enable transit encryption engine
kubectl exec -it vault-0 -n vault -- vault secrets enable transit

# Enable KV v2 secrets engine
kubectl exec -it vault-0 -n vault -- vault secrets enable -path=secret kv-v2

# Enable Kubernetes auth
kubectl exec -it vault-0 -n vault -- vault auth enable kubernetes
Step 13: Configure Kubernetes Auth
# Get Kubernetes details
KUBERNETES_HOST="https://kubernetes.default.svc:443"

# Get service account token
SA_JWT_TOKEN=$(kubectl get secret vault -n vault -o jsonpath='{.data.token}' | base64 -d)

# Get CA cert
SA_CA_CRT=$(kubectl get secret vault -n vault -o jsonpath='{.data.ca\.crt}' | base64 -d)

kubectl exec -it vault-0 -n vault -- sh -c '
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
'

# Configure Kubernetes auth
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/config \
  kubernetes_host="$KUBERNETES_HOST" \
  kubernetes_ca_cert="$SA_CA_CRT" \
  token_reviewer_jwt="$SA_JWT_TOKEN"
Step 14: Create Transit Encryption Key
kubectl exec -it vault-0 -n vault -- vault write -f transit/keys/tax-calculator
Step 15: Configure Database Connection
First, deploy PostgreSQL:
bash# Create PostgreSQL deployment
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: tax-calculator
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: tax-calculator
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        env:
        - name: POSTGRES_DB
          value: taxcalc
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          value: postgres123
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: tax-calculator
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF
Wait for PostgreSQL to be ready:
bashkubectl wait --for=condition=ready pod -l app=postgres -n tax-calculator --timeout=300s
Configure Vault database secrets:
bashkubectl exec -it vault-0 -n vault -- vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="tax-calculator-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres.tax-calculator.svc.cluster.local:5432/taxcalc?sslmode=disable" \
  username="postgres" \
  password="postgres123"

kubectl exec -it vault-0 -n vault -- vault write database/roles/tax-calculator-role \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT ALL PRIVILEGES ON DATABASE taxcalc TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"
Step 16: Create Vault Policy
bashkubectl exec -it vault-0 -n vault -- vault policy write tax-calculator - <<EOF
# Read dynamic database credentials
path "database/creds/tax-calculator-role" {
  capabilities = ["read"]
}

# Transit encryption
path "transit/encrypt/tax-calculator" {
  capabilities = ["update"]
}

path "transit/decrypt/tax-calculator" {
  capabilities = ["update"]
}

# KV secrets
path "secret/data/config/tax-calculator" {
  capabilities = ["read"]
}
EOF
Step 17: Create Kubernetes Role
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/tax-calculator \
  bound_service_account_names=tax-calculator \
  bound_service_account_namespaces=tax-calculator \
  policies=tax-calculator \
  ttl=1h

Phase 5: Deploy Application to Kubernetes 🚀
Step 18: Create Kubernetes Manifests
Create directory:
mkdir -p k8s
cd k8s
1. Namespace and ServiceAccount:
yaml# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tax-calculator
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tax-calculator
  namespace: tax-calculator
1. Backend Deployment:
yaml# backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: tax-calculator
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tax-calculator
      component: backend
  template:
    metadata:
      labels:
        app: tax-calculator
        component: backend
    spec:
      serviceAccountName: tax-calculator
      containers:
      - name: backend
        image: <AWS_ACCOUNT_ID>.dkr.ecr.eu-west-2.amazonaws.com/tax-calculator-backend:latest
        ports:
        - containerPort: 8080
        env:
        - name: VAULT_ADDR
          value: "http://vault.vault.svc.cluster.local:8200"
        - name: DATABASE_HOST
          value: "postgres.tax-calculator.svc.cluster.local"
        - name: DATABASE_PORT
          value: "5432"
        - name: DATABASE_NAME
          value: "taxcalc"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
1. Backend Service:
yaml# backend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: tax-calculator
spec:
  selector:
    app: tax-calculator
    component: backend
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
1. Frontend Deployment:
yaml# frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: tax-calculator
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tax-calculator
      component: frontend
  template:
    metadata:
      labels:
        app: tax-calculator
        component: frontend
    spec:
      containers:
      - name: frontend
        image: <AWS_ACCOUNT_ID>.dkr.ecr.eu-west-2.amazonaws.com/tax-calculator-frontend:latest
        ports:
        - containerPort: 80
        env:
        - name: REACT_APP_API_URL
          value: "http://backend.tax-calculator.svc.cluster.local:8080"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
1. Frontend Service (LoadBalancer):
yaml# frontend-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: tax-calculator
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
spec:
  selector:
    app: tax-calculator
    component: frontend
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
Step 19: Deploy Application
bash# Replace AWS_ACCOUNT_ID in manifests
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i '' "s/<AWS_ACCOUNT_ID>/$AWS_ACCOUNT_ID/g" *.yaml

# Apply manifests
kubectl apply -f namespace.yaml
kubectl apply -f backend-deployment.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f frontend-deployment.yaml
kubectl apply -f frontend-service.yaml

# Watch deployment
kubectl get pods -n tax-calculator -w
Step 20: Get Application URL
bashkubectl get svc frontend -n tax-calculator

# Wait for EXTERNAL-IP
# Takes 2-3 minutes for LoadBalancer to provision
Once you have the EXTERNAL-IP:
bashexport APP_URL=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$APP_URL"

Phase 6: Verify Application ✅
Step 21: Test Application
bash# Open in browser
open http://$APP_URL

# Or curl
curl http://$APP_URL
Step 22: Check Backend Logs
bashkubectl logs -n tax-calculator deployment/backend -f
Look for:

✅ Connected to Vault
✅ Got dynamic database credentials
✅ Database connection successful

Step 23: Test Tax Calculation
Go to http://$APP_URL and:

Enter income: 50000
Enter NI number: AB123456C
Tax year: 2024/2025
Click "Calculate Tax"

Expected result:

Income Tax: £7,486
NI: £4,504.80
Take Home: £38,009.20


oluwatobiakinlade@MacBookPro dev % kubectl exec -it vault-0 -n vault -- vault operator init
Recovery Key 1: 4kKrp+DyLQO6UIDgYNivC6R4cs3vyrITq60l9uC6WJ5g
Recovery Key 2: R9zmv7Issv9R7VbCroanEs/QHy5RLRyQaeM3jf4EGhEB
Recovery Key 3: dmLwkokogrQMxlm5PIa+0kM18spg/XQ/CZ2TZqlDJ+i4
Recovery Key 4: P385EdF2fJosTAn0Illg9pEKJn9zbcfBiiQYPJQV5WxA
Recovery Key 5: X6/5t4tDvOgAnQ0U21grAehJahDfOhhK7BLKHEBgjiLg
