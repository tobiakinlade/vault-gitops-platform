#!/bin/bash
set -e

# SRE Components Deployment Script
# SLI/SLO, Error Budgets, PrometheusRules, Dashboards

echo "📊 Deploying SRE Components..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "${YELLOW}Step 1: Deploy PrometheusRules for SLIs${NC}"

kubectl apply -f - <<EOF
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
        
        # Latency SLI (p99)
        - record: sli:latency:p99
          expr: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{namespace="tax-calculator",component="backend"}[5m]))
              by (le)
            )
        
        # Error Rate SLI
        - record: sli:errors:ratio_rate5m
          expr: |
            sum(rate(http_requests_total{namespace="tax-calculator",component="backend",status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total{namespace="tax-calculator",component="backend"}[5m]))
        
        # Request Rate
        - record: sli:requests:rate5m
          expr: |
            sum(rate(http_requests_total{namespace="tax-calculator",component="backend"}[5m]))

    - name: tax-calculator.slos
      interval: 1m
      rules:
        # Availability SLO: 99.9%
        - record: slo:availability:target
          expr: 0.999
        
        - record: slo:availability:remaining
          expr: |
            1 - (1 - slo:availability:target) -
            (1 - sli:availability:ratio_rate5m)
        
        # Latency SLO: p95 < 200ms
        - record: slo:latency:target_p95
          expr: 0.200  # 200ms
        
        - record: slo:latency:remaining_p95
          expr: |
            (slo:latency:target_p95 - sli:latency:p95) / slo:latency:target_p95
        
        # Error Budget (monthly)
        - record: slo:error_budget:monthly
          expr: |
            (1 - slo:availability:target) * 30 * 24 * 60 * 60  # seconds per month

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
        
        # Slow burn rate (24 hours)
        - record: slo:burn_rate:24h
          expr: |
            (
              1 - (
                sum(rate(http_requests_total{namespace="tax-calculator",component="backend",status!~"5.."}[24h]))
                /
                sum(rate(http_requests_total{namespace="tax-calculator",component="backend"}[24h]))
              )
            )
            /
            (1 - slo:availability:target)
EOF

echo "${GREEN}✅ SLI/SLO PrometheusRules deployed${NC}"

echo "${YELLOW}Step 2: Deploy Alerting Rules${NC}"

kubectl apply -f - <<EOF
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
        # Critical: Fast burn rate alert (5% budget in 1 hour)
        - alert: HighErrorBudgetBurnRate
          expr: |
            slo:burn_rate:1h > 14.4
          for: 5m
          labels:
            severity: critical
            component: backend
          annotations:
            summary: "High error budget burn rate detected"
            description: "Error budget is burning at {{ \$value }}x the normal rate. At this rate, the monthly budget will be exhausted in {{ humanizeDuration 2592000 | div \$value }} hours."
            runbook_url: "https://github.com/YOUR_ORG/runbooks/blob/main/high-burn-rate.md"
        
        # Warning: Slow burn rate alert
        - alert: ModerateErrorBudgetBurnRate
          expr: |
            slo:burn_rate:24h > 3
          for: 15m
          labels:
            severity: warning
            component: backend
          annotations:
            summary: "Moderate error budget burn rate"
            description: "Error budget is burning at {{ \$value }}x the normal rate over 24h."
        
        # Critical: SLO breach
        - alert: SLOAvailabilityBreach
          expr: |
            sli:availability:ratio_rate5m < slo:availability:target
          for: 5m
          labels:
            severity: critical
            component: backend
          annotations:
            summary: "Availability SLO breached"
            description: "Current availability {{ \$value | humanizePercentage }} is below target {{ slo:availability:target | humanizePercentage }}"
        
        # Warning: Latency SLO approaching
        - alert: LatencySLOApproaching
          expr: |
            sli:latency:p95 > (slo:latency:target_p95 * 0.9)
          for: 10m
          labels:
            severity: warning
            component: backend
          annotations:
            summary: "Latency approaching SLO target"
            description: "P95 latency {{ \$value }}s is approaching target {{ slo:latency:target_p95 }}s"
        
        # High error rate
        - alert: HighErrorRate
          expr: |
            sli:errors:ratio_rate5m > 0.05
          for: 5m
          labels:
            severity: warning
            component: backend
          annotations:
            summary: "High error rate detected"
            description: "Error rate {{ \$value | humanizePercentage }} is above 5%"
        
        # Pod availability
        - alert: PodDown
          expr: |
            kube_deployment_status_replicas_available{namespace="tax-calculator",deployment="backend"} < 1
          for: 2m
          labels:
            severity: critical
            component: backend
          annotations:
            summary: "Backend pods unavailable"
            description: "No backend pods available for {{ \$labels.deployment }}"
        
        # Database connectivity
        - alert: DatabaseDown
          expr: |
            up{job="postgres",namespace="tax-calculator"} == 0
          for: 2m
          labels:
            severity: critical
            component: database
          annotations:
            summary: "PostgreSQL database is down"
            description: "Cannot connect to PostgreSQL database"
        
        # Vault connectivity
        - alert: VaultDown
          expr: |
            up{job="vault",namespace="vault"} == 0
          for: 2m
          labels:
            severity: critical
            component: vault
          annotations:
            summary: "Vault is down"
            description: "Cannot connect to Vault service"
EOF

echo "${GREEN}✅ Alerting rules deployed${NC}"

echo "${YELLOW}Step 3: Create SLO Dashboard ConfigMap${NC}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: tax-calculator-slo-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  tax-calculator-slo.json: |
    {
      "dashboard": {
        "title": "Tax Calculator - SLO Dashboard",
        "tags": ["tax-calculator", "slo", "sre"],
        "timezone": "UTC",
        "schemaVersion": 16,
        "version": 1,
        "refresh": "30s",
        "time": {
          "from": "now-1h",
          "to": "now"
        },
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
            ],
            "yaxes": [
              {
                "format": "percent",
                "min": 99,
                "max": 100
              }
            ],
            "gridPos": {
              "x": 0,
              "y": 0,
              "w": 12,
              "h": 8
            }
          },
          {
            "id": 2,
            "title": "Latency SLI (p95) vs SLO",
            "type": "graph",
            "targets": [
              {
                "expr": "sli:latency:p95 * 1000",
                "legendFormat": "P95 Latency"
              },
              {
                "expr": "slo:latency:target_p95 * 1000",
                "legendFormat": "SLO Target (200ms)"
              }
            ],
            "yaxes": [
              {
                "format": "ms",
                "min": 0
              }
            ],
            "gridPos": {
              "x": 12,
              "y": 0,
              "w": 12,
              "h": 8
            }
          },
          {
            "id": 3,
            "title": "Error Budget Remaining",
            "type": "gauge",
            "targets": [
              {
                "expr": "slo:availability:remaining * 100"
              }
            ],
            "options": {
              "showThresholdLabels": false,
              "showThresholdMarkers": true
            },
            "fieldConfig": {
              "defaults": {
                "unit": "percent",
                "min": 0,
                "max": 100,
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {"value": 0, "color": "red"},
                    {"value": 25, "color": "orange"},
                    {"value": 50, "color": "yellow"},
                    {"value": 75, "color": "green"}
                  ]
                }
              }
            },
            "gridPos": {
              "x": 0,
              "y": 8,
              "w": 8,
              "h": 8
            }
          },
          {
            "id": 4,
            "title": "Burn Rate (1h)",
            "type": "stat",
            "targets": [
              {
                "expr": "slo:burn_rate:1h"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "unit": "none",
                "thresholds": {
                  "mode": "absolute",
                  "steps": [
                    {"value": 0, "color": "green"},
                    {"value": 2, "color": "yellow"},
                    {"value": 10, "color": "red"}
                  ]
                }
              }
            },
            "gridPos": {
              "x": 8,
              "y": 8,
              "w": 8,
              "h": 8
            }
          },
          {
            "id": 5,
            "title": "Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sli:requests:rate5m",
                "legendFormat": "Requests/sec"
              }
            ],
            "yaxes": [
              {
                "format": "reqps"
              }
            ],
            "gridPos": {
              "x": 16,
              "y": 8,
              "w": 8,
              "h": 8
            }
          }
        ]
      }
    }
EOF

echo "${GREEN}✅ SLO Dashboard created${NC}"

echo "${YELLOW}Step 4: Create Application Dashboard${NC}"

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: tax-calculator-app-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  tax-calculator-app.json: |
    {
      "dashboard": {
        "title": "Tax Calculator - Application Metrics",
        "tags": ["tax-calculator", "application"],
        "timezone": "UTC",
        "refresh": "30s",
        "panels": [
          {
            "id": 1,
            "title": "HTTP Request Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{namespace='tax-calculator'}[5m])) by (status)",
                "legendFormat": "{{status}}"
              }
            ],
            "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8}
          },
          {
            "id": 2,
            "title": "HTTP Request Latency",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{namespace='tax-calculator'}[5m])) by (le))",
                "legendFormat": "p50"
              },
              {
                "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace='tax-calculator'}[5m])) by (le))",
                "legendFormat": "p95"
              },
              {
                "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace='tax-calculator'}[5m])) by (le))",
                "legendFormat": "p99"
              }
            ],
            "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8}
          },
          {
            "id": 3,
            "title": "Error Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{namespace='tax-calculator',status=~'5..'}[5m])) / sum(rate(http_requests_total{namespace='tax-calculator'}[5m])) * 100",
                "legendFormat": "Error Rate %"
              }
            ],
            "gridPos": {"x": 0, "y": 8, "w": 12, "h": 8}
          },
          {
            "id": 4,
            "title": "Pod CPU Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(container_cpu_usage_seconds_total{namespace='tax-calculator',container!=''}[5m])) by (pod)",
                "legendFormat": "{{pod}}"
              }
            ],
            "gridPos": {"x": 12, "y": 8, "w": 12, "h": 8}
          },
          {
            "id": 5,
            "title": "Pod Memory Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(container_memory_working_set_bytes{namespace='tax-calculator',container!=''}) by (pod)",
                "legendFormat": "{{pod}}"
              }
            ],
            "gridPos": {"x": 0, "y": 16, "w": 12, "h": 8}
          },
          {
            "id": 6,
            "title": "Database Connections",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(pg_stat_database_numbackends{namespace='tax-calculator'})",
                "legendFormat": "Active Connections"
              }
            ],
            "gridPos": {"x": 12, "y": 16, "w": 12, "h": 8}
          }
        ]
      }
    }
EOF

echo "${GREEN}✅ Application Dashboard created${NC}"

echo ""
echo "${GREEN}=== SRE Components Deployed Successfully! ===${NC}"
echo ""
echo "SLI/SLO Framework:"
echo "  ✓ Availability SLI (99.9% target)"
echo "  ✓ Latency SLI (p95 < 200ms target)"
echo "  ✓ Error rate SLI"
echo "  ✓ Error budget tracking"
echo "  ✓ Burn rate calculations (1h, 24h)"
echo ""
echo "Alerting:"
echo "  ✓ High burn rate alerts"
echo "  ✓ SLO breach alerts"
echo "  ✓ Latency alerts"
echo "  ✓ Error rate alerts"
echo "  ✓ Service availability alerts"
echo ""
echo "Dashboards:"
echo "  ✓ SLO Dashboard (availability, latency, error budget)"
echo "  ✓ Application Dashboard (requests, errors, resources)"
echo ""
echo "Access Grafana to view dashboards:"
echo "  kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
echo "  Open: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
echo "Query Prometheus for SLI/SLO metrics:"
echo "  kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
echo "  Open: http://localhost:9090"
echo ""
echo "Example queries:"
echo "  sli:availability:ratio_rate5m"
echo "  sli:latency:p95"
echo "  slo:burn_rate:1h"
echo "  slo:error_budget:monthly"
