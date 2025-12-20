# 🚀 COMPLETE DEPLOYMENT GUIDE

**Tax Calculator with HashiCorp Vault - Ready for HMRC Interview**

## ⚡ Quick Deploy (30 Minutes)

This guide will get your application running from scratch in 30 minutes.

### Prerequisites Checklist

```bash
✅ Kubernetes cluster running (from Week 1)
✅ Vault installed and initialized
✅ kubectl configured
✅ Docker installed (for building images)
```

---

## 📋 Step-by-Step Deployment

### Step 1: Setup Vault (10 minutes)

```bash
# 1.1 Enable database secrets engine
kubectl exec -n vault vault-0 -- vault secrets enable database

# 1.2 Enable transit encryption
kubectl exec -n vault vault-0 -- vault secrets enable transit

# 1.3 Create transit encryption key
kubectl exec -n vault vault-0 -- vault write -f transit/keys/tax-calculator

# 1.4 Create Vault policy
cat <<EOF | kubectl exec -i -n vault vault-0 -- vault policy write tax-calculator -
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

# 1.5 Enable Kubernetes auth (if not already)
kubectl exec -n vault vault-0 -- vault auth enable kubernetes || true

# 1.6 Configure Kubernetes auth
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# 1.7 Create Kubernetes auth role
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/tax-calculator \
  bound_service_account_names=tax-calculator \
  bound_service_account_namespaces=default \
  policies=tax-calculator \
  ttl=24h

echo "✅ Vault configuration complete!"
```

### Step 2: Deploy PostgreSQL (5 minutes)

```bash
# 2.1 Create PostgreSQL deployment
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
  clusterIP: None
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
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
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "taxcalc"
        - name: POSTGRES_USER
          value: "postgres"
        - name: POSTGRES_PASSWORD
          value: "postgres123"  # Change in production!
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: gp3
      resources:
        requests:
          storage: 5Gi
EOF

# 2.2 Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s

echo "✅ PostgreSQL deployed!"
```

### Step 3: Configure Vault Database Connection (3 minutes)

```bash
# 3.1 Configure database connection in Vault
kubectl exec -n vault vault-0 -- vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="tax-calculator-role" \
  connection_url="postgresql://{{username}}:{{password}}@postgres.default.svc.cluster.local:5432/taxcalc?sslmode=disable" \
  username="postgres" \
  password="postgres123"

# 3.2 Create database role for dynamic credentials
kubectl exec -n vault vault-0 -- vault write database/roles/tax-calculator-role \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT ALL PRIVILEGES ON DATABASE taxcalc TO \"{{name}}\"; \
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# 3.3 Test dynamic credentials
echo "Testing Vault database credentials..."
kubectl exec -n vault vault-0 -- vault read database/creds/tax-calculator-role

echo "✅ Vault database configuration complete!"
```

### Step 4: Build and Deploy Backend (7 minutes)

```bash
# 4.1 Build backend image
cd backend
docker build -t tax-calculator-backend:latest .

# 4.2 (Optional) Push to registry
# docker tag tax-calculator-backend:latest your-registry/tax-calculator-backend:latest
# docker push your-registry/tax-calculator-backend:latest

# 4.3 Load image into kind (if using kind)
kind load docker-image tax-calculator-backend:latest --name vault-demo

# 4.4 Deploy backend
cd ..
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tax-calculator
---
apiVersion: v1
kind: Service
metadata:
  name: tax-calculator-backend
spec:
  selector:
    app: tax-calculator-backend
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tax-calculator-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tax-calculator-backend
  template:
    metadata:
      labels:
        app: tax-calculator-backend
    spec:
      serviceAccountName: tax-calculator
      containers:
      - name: backend
        image: tax-calculator-backend:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: VAULT_ADDR
          value: "http://vault.vault:8200"
        - name: VAULT_ROLE
          value: "tax-calculator"
        - name: DB_HOST
          value: "postgres"
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: "taxcalc"
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
EOF

# 4.5 Wait for backend to be ready
kubectl wait --for=condition=ready pod -l app=tax-calculator-backend --timeout=300s

echo "✅ Backend deployed!"
```

### Step 5: Build and Deploy Frontend (5 minutes)

```bash
# 5.1 Build frontend image
cd frontend
docker build -t tax-calculator-frontend:latest .

# 5.2 Load image into kind (if using kind)
kind load docker-image tax-calculator-frontend:latest --name vault-demo

# 5.3 Deploy frontend
cd ..
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: tax-calculator-frontend
spec:
  selector:
    app: tax-calculator-frontend
  ports:
    - port: 80
      targetPort: 80
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tax-calculator-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tax-calculator-frontend
  template:
    metadata:
      labels:
        app: tax-calculator-frontend
    spec:
      containers:
      - name: frontend
        image: tax-calculator-frontend:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        env:
        - name: REACT_APP_API_URL
          value: "http://tax-calculator-backend:8080"
EOF

# 5.4 Wait for frontend to be ready
kubectl wait --for=condition=ready pod -l app=tax-calculator-frontend --timeout=300s

echo "✅ Frontend deployed!"
```

---

## 🎯 Access Your Application

```bash
# Option 1: Port Forward (Quick)
kubectl port-forward svc/tax-calculator-frontend 3000:80

# Open browser: http://localhost:3000

# Option 2: LoadBalancer (if available)
kubectl get svc tax-calculator-frontend

# Option 3: Ingress (if configured)
# Access via your ingress URL
```

---

## ✅ Verification Checklist

```bash
# 1. Check all pods are running
kubectl get pods

# Expected output:
# NAME                                       READY   STATUS    RESTARTS   AGE
# postgres-0                                 1/1     Running   0          5m
# tax-calculator-backend-xxx                 1/1     Running   0          3m
# tax-calculator-backend-yyy                 1/1     Running   0          3m
# tax-calculator-frontend-xxx                1/1     Running   0          1m
# tax-calculator-frontend-yyy                1/1     Running   0          1m

# 2. Check backend health
kubectl port-forward svc/tax-calculator-backend 8080:8080 &
curl http://localhost:8080/health

# Expected: {"status":"healthy","database":"healthy","vault":"healthy"}

# 3. Test calculation
curl -X POST http://localhost:8080/api/v1/calculate \
  -H "Content-Type: application/json" \
  -d '{"income":50000,"national_insurance":"AB123456C","tax_year":"2024/2025"}'

# 4. Check Vault integration
kubectl logs -l app=tax-calculator-backend | grep Vault

# Expected: See Vault authentication and credential retrieval logs
```

---

## 🎪 Demo Checklist (For Interview)

```bash
✅ Application accessible via browser
✅ Can perform tax calculation
✅ Results show encrypted NI number
✅ History shows past calculations
✅ Backend logs show Vault integration
✅ Can demonstrate dynamic credentials
✅ Can show encrypted data in database
✅ Health checks pass for all services
```

---

## 🐛 Troubleshooting

### Backend Won't Start

```bash
# Check logs
kubectl logs -l app=tax-calculator-backend --tail=100

# Common issues:
# 1. Can't connect to Vault
kubectl exec -n vault vault-0 -- vault status

# 2. Service account missing
kubectl get sa tax-calculator

# 3. Vault policy not applied
kubectl exec -n vault vault-0 -- vault policy read tax-calculator
```

### Database Connection Fails

```bash
# Check PostgreSQL
kubectl exec -it postgres-0 -- psql -U postgres -d taxcalc -c "SELECT 1;"

# Check Vault database config
kubectl exec -n vault vault-0 -- vault read database/config/postgres

# Test dynamic credentials
kubectl exec -n vault vault-0 -- vault read database/creds/tax-calculator-role
```

### Frontend Can't Reach Backend

```bash
# Check service
kubectl get svc tax-calculator-backend

# Test backend directly
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://tax-calculator-backend:8080/health
```

---

## 🔄 Quick Teardown

```bash
# Delete all resources
kubectl delete deployment tax-calculator-backend tax-calculator-frontend
kubectl delete statefulset postgres
kubectl delete svc tax-calculator-backend tax-calculator-frontend postgres
kubectl delete sa tax-calculator
kubectl delete pvc postgres-data-postgres-0

# Clean up Vault (optional)
kubectl exec -n vault vault-0 -- vault secrets disable database
kubectl exec -n vault vault-0 -- vault secrets disable transit
kubectl exec -n vault vault-0 -- vault policy delete tax-calculator
kubectl exec -n vault vault-0 -- vault auth disable kubernetes/role/tax-calculator
```

---

## 📝 Next Steps for Interview Prep

1. ✅ **Practice the demo** - Can you deploy in < 5 minutes?
2. ✅ **Memorize talking points** - See README.md
3. ✅ **Prepare questions** - What they might ask
4. ✅ **Test failure scenarios** - Kill pods, rotate credentials
5. ✅ **Document your learnings** - What you discovered

---

## 🎓 Interview Day Checklist

**Day Before:**
- [ ] Test complete deployment end-to-end
- [ ] Record a practice demo video
- [ ] Review Vault concepts
- [ ] Prepare 3 technical questions to ask

**Interview Day:**
- [ ] Have deployment working before call
- [ ] Terminal ready with commands
- [ ] Browser tabs prepared
- [ ] Backup slides/diagrams ready
- [ ] Calm, confident, ready to impress! 🚀

---

**You've got this, Tobi!** This is a solid, production-ready demo that shows you understand government security requirements. Good luck with your HMRC interview on January 8th! 💪
