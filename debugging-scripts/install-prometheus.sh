#!/bin/bash

set -e

echo "=== Installing Prometheus Stack ==="
echo ""

# Add Prometheus Helm repository
echo "Step 1: Adding Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
echo "✅ Helm repo updated"
echo ""

# Create Prometheus values file
echo "Step 2: Creating values file..."
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
  adminPassword: "admin123"
  
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

echo "✅ Values file created"
echo ""

# Create namespace
echo "Step 3: Creating namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"
echo ""

# Install Prometheus stack
echo "Step 4: Installing Prometheus stack (this takes 5-10 minutes)..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values prometheus-values.yaml \
  --version 67.2.0 \
  --wait \
  --timeout 15m

echo "✅ Installation complete"
echo ""

# Verify deployment
echo "Step 5: Verifying deployment..."
kubectl get pods -n monitoring
echo ""

# Check PVCs
echo "Step 6: Checking storage..."
kubectl get pvc -n monitoring
echo ""

# Wait for LoadBalancer
echo "Step 7: Waiting for LoadBalancer (30 seconds)..."
sleep 30

# Get Grafana URL
GRAFANA_URL=$(kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "========================================"
echo "🎉 INSTALLATION COMPLETE!"
echo "========================================"
echo ""
echo "📊 Grafana Dashboard:"
echo "   URL:      http://${GRAFANA_URL}"
echo "   Username: admin"
echo "   Password: admin123"
echo ""
echo "📈 Prometheus UI:"
echo "   Run: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "   Then: http://localhost:9090"
echo ""
echo "🚨 AlertManager UI:"
echo "   Run: kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
echo "   Then: http://localhost:9093"
echo ""
echo "========================================"
echo ""
echo "✅ All components deployed:"
kubectl get all -n monitoring -l "release=kube-prometheus-stack"
echo ""
echo "Next: Open Grafana and explore dashboards!"
