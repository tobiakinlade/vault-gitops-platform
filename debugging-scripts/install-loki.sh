#!/bin/bash

set -e

echo "=== Installing Loki Stack for Logging ==="
echo ""

# Add Helm repo
echo "Step 1: Adding Grafana Helm repository..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
echo "✅ Helm repo updated"
echo ""

# Create namespace
echo "Step 2: Creating namespace..."
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"
echo ""

# Create values file
echo "Step 3: Creating Loki values..."
cat > loki-values.yaml <<'EOF'
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  
  storage:
    type: filesystem
  
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

deploymentMode: SingleBinary

singleBinary:
  replicas: 1
  
  persistence:
    enabled: true
    storageClass: gp3
    size: 30Gi
  
  resources:
    requests:
      cpu: 200m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

promtail:
  enabled: true
  
  config:
    clients:
      - url: http://{{ .Release.Name }}-gateway/loki/api/v1/push
    
    positions:
      filename: /tmp/positions.yaml
    
    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_node_name]
            target_label: node_name
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container
          - source_labels: [__meta_kubernetes_namespace]
            action: drop
            regex: kube-system
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

gateway:
  enabled: true
  replicas: 1
  
  service:
    type: ClusterIP
  
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

monitoring:
  selfMonitoring:
    enabled: false
    grafanaAgent:
      installOperator: false

backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0
EOF

echo "✅ Values file created"
echo ""

# Install Loki
echo "Step 4: Installing Loki (5-7 minutes)..."
helm upgrade --install loki grafana/loki \
  --namespace logging \
  --create-namespace \
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

kubectl get pvc -n logging
echo ""

# Add datasource to Grafana
echo "Step 6: Configuring Grafana datasource..."
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
        editable: true
DSEOF

echo "✅ Datasource configured"
echo ""

# Restart Grafana
echo "Step 7: Restarting Grafana to load datasource..."
kubectl rollout restart deployment -n monitoring kube-prometheus-stack-grafana
kubectl rollout status deployment -n monitoring kube-prometheus-stack-grafana --timeout=300s

echo "✅ Grafana restarted"
echo ""

# Test connection
echo "Step 8: Testing Loki..."
sleep 10

kubectl port-forward -n logging svc/loki-gateway 3100:80 >/dev/null 2>&1 &
PF_PID=$!
sleep 5

curl -s "http://localhost:3100/loki/api/v1/label" >/dev/null 2>&1 && echo "✅ Loki is responding" || echo "⚠️  Loki not ready yet, wait 1 minute"

kill $PF_PID 2>/dev/null

echo ""
echo "========================================"
echo "🎉 LOKI INSTALLATION COMPLETE!"
echo "========================================"
echo ""
echo "Components installed:"
kubectl get all -n logging
echo ""
echo "Grafana datasource:"
echo "  Name: Loki"
echo "  URL:  http://loki-gateway.logging.svc.cluster.local"
echo ""
GRAFANA_URL=$(kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Open Grafana: http://${GRAFANA_URL}"
echo "Go to: Explore → Select 'Loki' datasource"
echo "Try query: {namespace=\"tax-calculator\"}"
echo ""
echo "========================================"
