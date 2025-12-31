#!/bin/bash

set -e

echo "=== Installing Loki Stack with Schema Configuration ==="
echo ""

# Uninstall if exists
echo "Step 1: Cleaning up old installation..."
helm uninstall loki -n logging 2>/dev/null || echo "No previous installation found"
sleep 5
kubectl delete pvc -n logging --all 2>/dev/null || true
echo "✅ Cleanup complete"
echo ""

# Add Helm repo
echo "Step 2: Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
echo "✅ Helm repo updated"
echo ""

# Create namespace
echo "Step 3: Creating namespace..."
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"
echo ""

# Install Loki
echo "Step 4: Installing Loki with schema config (5-7 minutes)..."
helm install loki grafana/loki \
  --namespace logging \
  --values loki-values.yaml \
  --version 6.16.0 \
  --wait \
  --timeout 10m

echo "✅ Loki installed"
echo ""

# Verify
echo "Step 5: Verifying installation..."
kubectl get pods -n logging
echo ""

echo "Step 6: Checking storage..."
kubectl get pvc -n logging
echo ""

# Wait for Loki to be ready
echo "Step 7: Waiting for Loki to be ready..."
kubectl wait --for=condition=ready pod -n logging -l app.kubernetes.io/name=loki --timeout=300s

# Test Loki
echo ""
echo "Step 8: Testing Loki API..."
kubectl port-forward -n logging svc/loki-gateway 3100:80 >/dev/null 2>&1 &
PF_PID=$!
sleep 5

LOKI_STATUS=$(curl -s http://localhost:3100/ready)
if [ "$LOKI_STATUS" = "ready" ]; then
  echo "✅ Loki is ready and responding"
else
  echo "⚠️  Loki status: $LOKI_STATUS"
fi

kill $PF_PID 2>/dev/null

echo ""
echo "Step 9: Configuring Grafana datasource..."

# Add datasource to Grafana
cat <<DSEOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |-
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki-gateway.logging.svc.cluster.local
        jsonData:
          maxLines: 1000
        isDefault: false
        editable: true
DSEOF

echo "✅ Datasource configured"
echo ""

# Restart Grafana to pick up datasource
echo "Step 10: Restarting Grafana..."
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-grafana
kubectl rollout status deployment -n monitoring kube-prometheus-stack-grafana --timeout=300s

echo "✅ Grafana restarted"
echo ""

# Final status
echo "========================================"
echo "🎉 LOKI INSTALLATION COMPLETE!"
echo "========================================"
echo ""
echo "📊 Pods in logging namespace:"
kubectl get pods -n logging
echo ""
echo "💾 Storage:"
kubectl get pvc -n logging
echo ""

GRAFANA_URL=$(kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "📈 Access Grafana: http://${GRAFANA_URL}"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "🔍 To view logs:"
echo "   1. Open Grafana"
echo "   2. Go to Explore (compass icon)"
echo "   3. Select 'Loki' datasource"
echo "   4. Try: {namespace=\"tax-calculator\"}"
echo ""
echo "========================================"
