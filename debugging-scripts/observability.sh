#!/bin/bash

set -e

echo "=== Installing Prometheus Stack with Observability ==="
echo ""

# Check prerequisites
echo "Step 1: Checking prerequisites..."
kubectl get storageclass gp3 || {
  echo "Creating gp3 storage class..."
  cat <<SCEOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
SCEOF
}
echo "✅ Storage class ready"
echo ""

# Clean up old installation if exists
echo "Step 2: Cleaning up old installation..."
helm uninstall prometheus-stack -n observability 2>/dev/null || echo "No previous installation found"
sleep 5
kubectl delete pvc -n observability --all 2>/dev/null || true
echo "✅ Cleanup complete"
echo ""

# Add helm repo
echo "Step 3: Adding Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
echo "✅ Helm repo updated"
echo ""

# Install
echo "Step 4: Installing Prometheus Stack (this takes 3-5 minutes)..."
helm install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --values prometheus-stack-values.yaml \
  --timeout 10m \
  --wait

echo "✅ Installation complete"
echo ""

# Verify
echo "Step 5: Verifying installation..."
kubectl get pods -n observability
echo ""

echo "Step 6: Checking PVCs..."
kubectl get pvc -n observability
echo ""

# Get Grafana URL
echo "Step 7: Getting Grafana URL..."
sleep 30  # Wait for LoadBalancer
GRAFANA_URL=$(kubectl get svc -n observability prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "================================================"
echo "🎉 INSTALLATION COMPLETE!"
echo "================================================"
echo ""
echo "Grafana:"
echo "  URL:      http://${GRAFANA_URL}"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Prometheus:"
echo "  Port-forward: kubectl port-forward -n observability svc/prometheus-stack-kube-prom-prometheus 9090:9090"
echo "  Then access: http://localhost:9090"
echo ""
echo "AlertManager:"
echo "  Port-forward: kubectl port-forward -n observability svc/prometheus-stack-kube-prom-alertmanager 9093:9093"
echo "  Then access: http://localhost:9093"
echo ""
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Open Grafana and explore pre-installed dashboards"
echo "2. Add ServiceMonitors for tax-calculator application"
echo "3. Create custom dashboards"
echo "4. Configure alerts"
