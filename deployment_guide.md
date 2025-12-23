✅ Prerequisites Check
bash# Verify infrastructure is ready
kubectl get nodes
# Should show 3 nodes Ready

kubectl get pods -n vault
# Should show vault-0, vault-1 Running

kubectl get pods -n kube-system | grep ebs
# Should show ebs-csi-* pods Running

🔐 PHASE 1: Initialize Vault (5 minutes)
1.1 Initialize Vault
bash 
kubectl exec -it vault-0 -n vault -- vault operator init | tee vault-keys.txt
Output will show:

5 Recovery Keys
1 Initial Root Token

📝 CRITICAL: Save vault-keys.txt in a safe place!
1.2 Extract Root Token
bash# View your keys
cat vault-keys.txt

# Extract root token (at the bottom)
export ROOT_TOKEN=$(grep "Initial Root Token:" vault-keys.txt | awk '{print $4}')
echo "Your Root Token: $ROOT_TOKEN"
1.3 Login to Vault
bash 
kubectl exec -it vault-0 -n vault -- vault login $ROOT_TOKEN
Expected: "Success! You are now authenticated."
1.4 Verify Vault Status
bash kubectl exec -it vault-0 -n vault -- vault status
```

**Expected:**
```
Sealed: false
Initialized: true

⚙️ PHASE 2: Configure Vault Secret Engines (3 minutes)
2.1 Enable All Secret Engines
bash 
kubectl exec -it vault-0 -n vault -- vault secrets enable database
kubectl exec -it vault-0 -n vault -- vault secrets enable transit
kubectl exec -it vault-0 -n vault -- vault secrets enable -path=secret kv-v2
kubectl exec -it vault-0 -n vault -- vault auth enable kubernetes
2.2 Configure Kubernetes Authentication
bash 
kubectl exec -it vault-0 -n vault -- sh -c '
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
'
Expected: "Success! Data written to: auth/kubernetes/config"
2.3 Create Transit Encryption Key
bash kubectl exec -it vault-0 -n vault -- vault write -f transit/keys/tax-calculator
Expected: "Success! Data written to: transit/keys/tax-calculator"
2.4 Create Vault Policy
bash 
kubectl exec -it vault-0 -n vault -- vault policy write tax-calculator - <<EOF
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
EOF

Expected: "Success! Uploaded policy: tax-calculator"
2.5 Create Kubernetes Role
bash 
kubectl exec -it vault-0 -n vault -- vault write auth/kubernetes/role/tax-calculator \
  bound_service_account_names=tax-calculator \
  bound_service_account_namespaces=tax-calculator \
  policies=tax-calculator \
  ttl=1h

Expected: "Success! Data written to: auth/kubernetes/role/tax-calculator"

🗄️ PHASE 3: Deploy PostgreSQL (2 minutes)
3.1 Create Namespace & Deploy PostgreSQL
bash 
kubectl apply -f - <<EOF
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
      app: tax-calculator
      component: database
  template:
    metadata:
      labels:
        app: tax-calculator
        component: database
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
          subPath: postgres
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
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
    app: tax-calculator
    component: database
  ports:
  - port: 5432
    targetPort: 5432
EOF
3.2 Wait for PostgreSQL
bash kubectl wait --for=condition=ready pod -l component=database -n tax-calculator --timeout=300s
Expected: "pod/postgres-xxx condition met"

🔗 PHASE 4: Configure Database Secrets (2 minutes)
4.1 Configure Database Connection
bash kubectl exec -it vault-0 -n vault -- vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="tax-calculator-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres.tax-calculator.svc.cluster.local:5432/taxcalc?sslmode=disable" \
  username="postgres" \
  password="postgres123"
Expected: "Success! Data written to: database/config/postgres"
4.2 Create Database Role
<!-- bash kubectl exec -it vault-0 -n vault -- vault write database/roles/tax-calculator-role \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON DATABASE taxcalc TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h" -->
Expected: "Success! Data written to: database/roles/tax-calculator-role"

kubectl exec -it vault-0 -n vault -- vault write database/roles/tax-calculator-role \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT ALL PRIVILEGES ON DATABASE taxcalc TO \"{{name}}\"; \
    GRANT ALL ON SCHEMA public TO \"{{name}}\"; \
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\"; \
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO \"{{name}}\"; \
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"


4.3 Test Dynamic Credentials
bash kubectl exec -it vault-0 -n vault -- vault read database/creds/tax-calculator-role
Expected: Should show username and password ✅

🐳 PHASE 5: Build & Push Docker Images (10 minutes)
5.1 Set Environment Variables
bash export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="eu-west-2"

<!-- echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
5.2 Create ECR Repositories
bashaws ecr create-repository \
  --repository-name tax-calculator-backend \
  --region $AWS_REGION \
  --image-scanning-configuration scanOnPush=true

aws ecr create-repository \
  --repository-name tax-calculator-frontend \
  --region $AWS_REGION \
  --image-scanning-configuration scanOnPush=true -->
5.3 Login to ECR
bash aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
Expected: "Login Succeeded"
5.4 Build & Push Backend
bash cd tax-calculator-app/backend

docker build -t tax-calculator-backend:latest .

docker tag tax-calculator-backend:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/tax-calculator-backend:latest

docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/tax-calculator-backend:latest

cd ../..
5.5 Build & Push Frontend
bashcd tax-calculator-app/frontend

docker build -t tax-calculator-frontend:latest .

docker tag tax-calculator-frontend:latest \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/tax-calculator-frontend:latest

docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/tax-calculator-frontend:latest

cd ../..

☸️ PHASE 6: Deploy Application (5 minutes)
6.1 Create/Update Kubernetes Manifests
bash cd tax-calculator-app/k8s

# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
6.2 Create Backend Deployment
bash cat > backend-deployment.yaml <<EOF
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
        image: ${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-2.amazonaws.com/tax-calculator-backend:latest
        ports:
        - containerPort: 8080
        env:
        - name: VAULT_ADDR
          value: "http://vault.vault.svc.cluster.local:8200"
        - name: VAULT_ROLE
          value: "tax-calculator"
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
EOF
6.3 Create Backend Service

bash cat > backend-service.yaml <<'EOF'
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
EOF
6.4 Create Frontend Deployment
bash cat > frontend-deployment.yaml <<EOF
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
        image: ${AWS_ACCOUNT_ID}.dkr.ecr.eu-west-2.amazonaws.com/tax-calculator-frontend:latest
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
EOF
6.5 Create Frontend Service
bash cat > frontend-service.yaml <<'EOF'
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
EOF
6.6 Deploy Application
bash 
kubectl apply -f backend-deployment.yaml
kubectl apply -f backend-service.yaml
kubectl apply -f frontend-deployment.yaml
kubectl apply -f frontend-service.yaml
6.7 Watch Deployment
bash kubectl get pods -n tax-calculator -w
Wait until all pods show Running (Press Ctrl+C to exit)

🌐 PHASE 7: Access Application (3 minutes)
7.1 Get LoadBalancer URL
bash# Wait for EXTERNAL-IP (takes 2-3 minutes)
kubectl get svc frontend -n tax-calculator
Watch for EXTERNAL-IP to appear (won't say <pending>)
7.2 Get Application URL
bash export APP_URL=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo ""
echo "=========================================="
echo "🎉 Application URL: http://$APP_URL"
echo "=========================================="
echo ""
7.3 Open Application
bash# macOS
open http://$APP_URL

# Linux
xdg-open http://$APP_URL

# Or manually copy-paste the URL into your browser

✅ PHASE 8: Test & Verify
8.1 Test Tax Calculation
In your browser at http://$APP_URL:
Input:

Income: £50,000
NI Number: AB123456C
Tax Year: 2024/2025

Click "Calculate Tax"
Expected Output:

Income Tax: £7,486
National Insurance: £4,504.80
Take Home: £38,009.20

8.2 Check Backend Logs
bash kubectl logs -n tax-calculator deployment/backend --tail=50
Should see:

✅ Connected to Vault
✅ Retrieved database credentials
✅ Database connection successful

8.3 Verify All Components
bashecho "=== Infrastructure Status ==="
echo ""
echo "Vault:"
kubectl get pods -n vault
echo ""
echo "Application:"
kubectl get pods -n tax-calculator
echo ""
echo "Services:"
kubectl get svc -n tax-calculator
echo ""
echo "Nodes:"
kubectl top nodes

📋 Complete Status Check
bash#!/bin/bash
echo "=========================================="
echo "Tax Calculator Deployment Status"
echo "=========================================="
echo ""

echo "✅ Vault Status:"
kubectl exec -it vault-0 -n vault -- vault status | grep -E "Sealed|Initialized"
echo ""

echo "✅ Secret Engines:"
kubectl exec -it vault-0 -n vault -- vault secrets list | grep -E "database|transit|secret"
echo ""

echo "✅ Kubernetes Auth:"
kubectl exec -it vault-0 -n vault -- vault auth list | grep kubernetes
echo ""

echo "✅ PostgreSQL:"
kubectl get pods -n tax-calculator -l component=database
echo ""

echo "✅ Backend:"
kubectl get pods -n tax-calculator -l component=backend
echo ""

echo "✅ Frontend:"
kubectl get pods -n tax-calculator -l component=frontend
echo ""

echo "✅ Application URL:"
kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
echo ""

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="

🎯 Success Criteria
✅ Vault initialized and unsealed
✅ All secret engines enabled
✅ PostgreSQL running
✅ Dynamic database credentials working
✅ Backend pods running (2 replicas)
✅ Frontend pods running (2 replicas)
✅ LoadBalancer provisioned
✅ Application accessible
✅ Tax calculation returns correct results

🧹 Cleanup (When Done)
bash# Delete application
kubectl delete namespace tax-calculator

# Destroy infrastructure
cd terraform/environments/dev
terraform destroy -auto-approve
