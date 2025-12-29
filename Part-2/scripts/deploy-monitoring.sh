#!/bin/bash
set -e

# Observability Stack Deployment Script
# Day 4-5: Prometheus, Grafana, Loki, AlertManager

echo "🚀 Deploying Observability Stack..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Add Helm repositories
echo "${YELLOW}Adding Helm repositories...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo "${GREEN}✅ Helm repositories added${NC}"

# Create monitoring namespace
echo "${YELLOW}Creating monitoring namespace...${NC}"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Deploy Prometheus Stack (includes Grafana, AlertManager)
echo "${YELLOW}Deploying Prometheus Stack...${NC}"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --version 55.5.0 \
  --values - <<EOF
# Prometheus Configuration
prometheus:
  prometheusSpec:
    retention: 30d
    retentionSize: "50GB"
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
          storageClassName: gp3
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 4Gi
    # Service Monitors for automatic discovery
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    # Scrape interval
    scrapeInterval: 15s
    evaluationInterval: 15s

# Grafana Configuration
grafana:
  enabled: true
  adminPassword: "admin123"  # CHANGE THIS!
  persistence:
    enabled: true
    size: 10Gi
    storageClassName: gp3
  service:
    type: LoadBalancer
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi
  # Data sources
  additionalDataSources:
    - name: Loki
      type: loki
      url: http://loki-gateway.logging.svc.cluster.local
      access: proxy
      isDefault: false
    - name: Prometheus
      type: prometheus
      url: http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090
      access: proxy
      isDefault: true
  # Dashboard providers
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'default'
          orgId: 1
          folder: ''
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/default
        - name: 'application'
          orgId: 1
          folder: 'Application'
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards/application
  dashboards:
    default:
      # Kubernetes cluster monitoring
      kubernetes-cluster:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
      # Node exporter
      node-exporter:
        gnetId: 1860
        revision: 31
        datasource: Prometheus
      # Pod monitoring
      kubernetes-pods:
        gnetId: 6417
        revision: 1
        datasource: Prometheus

# AlertManager Configuration
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
          storageClassName: gp3
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'default'
      routes:
        - match:
            alertname: Watchdog
          receiver: 'null'
        - match:
            severity: critical
          receiver: 'critical'
        - match:
            severity: warning
          receiver: 'warning'
    receivers:
      - name: 'null'
      - name: 'default'
        # Add Slack, PagerDuty, email here
      - name: 'critical'
        # Critical alerts
      - name: 'warning'
        # Warning alerts

# Node Exporter
prometheus-node-exporter:
  resources:
    requests:
      cpu: 100m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

# Kube State Metrics
kube-state-metrics:
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
EOF

echo "${BLUE}Waiting for Prometheus Stack to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

echo "${GREEN}✅ Prometheus Stack deployed${NC}"

# Deploy Loki
echo "${YELLOW}Deploying Loki...${NC}"
helm upgrade --install loki grafana/loki \
  --namespace logging \
  --create-namespace \
  --version 5.41.0 \
  --values - <<EOF
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: 'filesystem'
  schemaConfig:
    configs:
      - from: 2024-01-01
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  
  # Retention (30 days)
  limits_config:
    retention_period: 720h
    max_query_length: 721h

# Single binary mode for simplicity
deploymentMode: SingleBinary

singleBinary:
  replicas: 1
  persistence:
    enabled: true
    size: 30Gi
    storageClass: gp3
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi

# Enable gateway
gateway:
  enabled: true
  service:
    type: ClusterIP
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

# Monitoring
monitoring:
  serviceMonitor:
    enabled: true
  selfMonitoring:
    enabled: false
    grafanaAgent:
      installOperator: false

# Test
test:
  enabled: false
EOF

echo "${BLUE}Waiting for Loki to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=single-binary -n logging --timeout=300s

echo "${GREEN}✅ Loki deployed${NC}"

# Deploy Promtail
echo "${YELLOW}Deploying Promtail (log collector)...${NC}"
helm upgrade --install promtail grafana/promtail \
  --namespace logging \
  --version 6.15.3 \
  --values - <<EOF
config:
  clients:
    - url: http://loki-gateway.logging.svc.cluster.local/loki/api/v1/push

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Tolerations for all nodes
tolerations:
  - effect: NoSchedule
    operator: Exists

# Priority
priorityClassName: system-node-critical
EOF

echo "${BLUE}Waiting for Promtail to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=promtail -n logging --timeout=300s

echo "${GREEN}✅ Promtail deployed${NC}"

# Get access information
echo ""
echo "${GREEN}=== Observability Stack Deployed Successfully! ===${NC}"
echo ""

# Grafana
GRAFANA_URL=$(kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana:"
echo "  URL: http://${GRAFANA_URL}"
echo "  Username: admin"
echo "  Password: admin123"  # CHANGE THIS!
echo ""

# Prometheus
echo "Prometheus:"
echo "  Port-forward: kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
echo "  URL: http://localhost:9090"
echo ""

# AlertManager
echo "AlertManager:"
echo "  Port-forward: kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093"
echo "  URL: http://localhost:9093"
echo ""

# Loki
echo "Loki:"
echo "  URL (internal): http://loki-gateway.logging.svc.cluster.local"
echo "  Query via Grafana"
echo ""

echo "Next steps:"
echo "1. Access Grafana and explore dashboards"
echo "2. Configure additional data sources if needed"
echo "3. Create custom dashboards for tax-calculator application"
echo "4. Set up AlertManager receivers (Slack, PagerDuty, etc.)"
