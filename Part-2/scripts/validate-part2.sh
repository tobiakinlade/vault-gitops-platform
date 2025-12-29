#!/bin/bash

# Part 2 Validation Script
# Comprehensive validation of all components

echo "🔍 Validating Part 2 Implementation..."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Helper function
check_pods() {
    NAMESPACE=$1
    LABEL=$2
    NAME=$3
    
    echo -n "  Checking $NAME pods in $NAMESPACE... "
    READY=$(kubectl get pods -n $NAMESPACE -l $LABEL -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -o "True" | wc -l)
    TOTAL=$(kubectl get pods -n $NAMESPACE -l $LABEL --no-headers 2>/dev/null | wc -l)
    
    if [ "$READY" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} ($READY/$TOTAL ready)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} ($READY/$TOTAL ready)"
        ((FAILED++))
        return 1
    fi
}

check_service() {
    NAMESPACE=$1
    SERVICE=$2
    NAME=$3
    
    echo -n "  Checking $NAME service in $NAMESPACE... "
    if kubectl get svc $SERVICE -n $NAMESPACE &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
        return 1
    fi
}

echo ""
echo "================================"
echo " GitOps (ArgoCD) Validation"
echo "================================"
check_pods "argocd" "app.kubernetes.io/name=argocd-server" "ArgoCD Server"
check_pods "argocd" "app.kubernetes.io/name=argocd-repo-server" "ArgoCD Repo Server"
check_pods "argocd" "app.kubernetes.io/name=argocd-application-controller" "ArgoCD Application Controller"
check_service "argocd" "argocd-server" "ArgoCD Server"

echo ""
echo "================================"
echo " Observability Stack Validation"
echo "================================"
check_pods "monitoring" "app.kubernetes.io/name=prometheus" "Prometheus"
check_pods "monitoring" "app.kubernetes.io/name=grafana" "Grafana"
check_pods "monitoring" "app.kubernetes.io/name=alertmanager" "AlertManager"
check_pods "monitoring" "app.kubernetes.io/name=prometheus-node-exporter" "Node Exporter"
check_service "monitoring" "kube-prometheus-stack-prometheus" "Prometheus Service"
check_service "monitoring" "kube-prometheus-stack-grafana" "Grafana Service"

echo ""
echo "================================"
echo " Logging Stack Validation"
echo "================================"
check_pods "logging" "app.kubernetes.io/component=single-binary" "Loki"
check_pods "logging" "app.kubernetes.io/name=promtail" "Promtail"
check_service "logging" "loki-gateway" "Loki Gateway"

echo ""
echo "================================"
echo " ELK Stack Validation"
echo "================================"
check_pods "elastic-system" "app=elasticsearch-master" "Elasticsearch"
check_pods "elastic-system" "app=kibana" "Kibana"
check_pods "elastic-system" "app=fluentd" "Fluentd"
check_service "elastic-system" "elasticsearch-master" "Elasticsearch Service"
check_service "elastic-system" "kibana-kibana" "Kibana Service"

echo ""
echo "================================"
echo " Application Validation"
echo "================================"
check_pods "tax-calculator" "component=backend" "Backend"
check_pods "tax-calculator" "component=frontend" "Frontend"
check_pods "tax-calculator" "component=database" "PostgreSQL"
check_service "tax-calculator" "backend" "Backend Service"
check_service "tax-calculator" "frontend" "Frontend Service"
check_service "tax-calculator" "postgres" "PostgreSQL Service"

echo ""
echo "================================"
echo " Vault Validation"
echo "================================"
check_pods "vault" "app.kubernetes.io/name=vault" "Vault"
check_service "vault" "vault" "Vault Service"

echo ""
echo "================================"
echo " Storage Validation"
echo "================================"
echo -n "  Checking Persistent Volume Claims... "
PVC_COUNT=$(kubectl get pvc --all-namespaces -o json | jq '.items | length')
PVC_BOUND=$(kubectl get pvc --all-namespaces -o json | jq '[.items[] | select(.status.phase=="Bound")] | length')
if [ "$PVC_COUNT" -eq "$PVC_BOUND" ]; then
    echo -e "${GREEN}✓${NC} ($PVC_BOUND/$PVC_COUNT bound)"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} ($PVC_BOUND/$PVC_COUNT bound)"
    ((FAILED++))
fi

echo ""
echo "================================"
echo " Network Validation"
echo "================================"
echo -n "  Checking LoadBalancer services... "
LB_COUNT=$(kubectl get svc --all-namespaces -o json | jq '[.items[] | select(.spec.type=="LoadBalancer")] | length')
LB_READY=$(kubectl get svc --all-namespaces -o json | jq '[.items[] | select(.spec.type=="LoadBalancer" and .status.loadBalancer.ingress!=null)] | length')
if [ "$LB_COUNT" -eq "$LB_READY" ]; then
    echo -e "${GREEN}✓${NC} ($LB_READY/$LB_COUNT ready)"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} ($LB_READY/$LB_COUNT ready) - Some LoadBalancers pending"
    ((WARNINGS++))
fi

echo ""
echo "================================"
echo " Metrics & Monitoring"
echo "================================"
echo -n "  Checking ServiceMonitors... "
SM_COUNT=$(kubectl get servicemonitors --all-namespaces -o json 2>/dev/null | jq '.items | length')
if [ "$SM_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} ($SM_COUNT found)"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} No ServiceMonitors found"
    ((WARNINGS++))
fi

echo ""
echo "================================"
echo " ArgoCD Applications"
echo "================================"
echo -n "  Checking ArgoCD Applications... "
APPS=$(kubectl get applications -n argocd -o json 2>/dev/null | jq '.items | length')
SYNCED=$(kubectl get applications -n argocd -o json 2>/dev/null | jq '[.items[] | select(.status.sync.status=="Synced")] | length')
HEALTHY=$(kubectl get applications -n argocd -o json 2>/dev/null | jq '[.items[] | select(.status.health.status=="Healthy")] | length')

if [ "$APPS" -gt 0 ]; then
    echo ""
    echo "    Total Applications: $APPS"
    echo -n "    Synced: "
    if [ "$SYNCED" -eq "$APPS" ]; then
        echo -e "${GREEN}✓${NC} ($SYNCED/$APPS)"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} ($SYNCED/$APPS)"
        ((FAILED++))
    fi
    
    echo -n "    Healthy: "
    if [ "$HEALTHY" -eq "$APPS" ]; then
        echo -e "${GREEN}✓${NC} ($HEALTHY/$APPS)"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} ($HEALTHY/$APPS)"
        ((FAILED++))
    fi
else
    echo -e "${YELLOW}⚠${NC} No ArgoCD Applications found"
    ((WARNINGS++))
fi

echo ""
echo "================================"
echo " Health Checks"
echo "================================"

# Prometheus health
echo -n "  Prometheus health... "
if kubectl exec -n monitoring $(kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}') -- wget -qO- http://localhost:9090/-/healthy 2>/dev/null | grep -q "Prometheus"; then
    echo -e "${GREEN}✓${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗${NC}"
    ((FAILED++))
fi

# Grafana health
echo -n "  Grafana health... "
if kubectl exec -n monitoring $(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}') -- wget -qO- http://localhost:3000/api/health 2>/dev/null | grep -q "ok"; then
    echo -e "${GREEN}✓${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗${NC}"
    ((FAILED++))
fi

# Elasticsearch health
echo -n "  Elasticsearch health... "
if kubectl exec -n elastic-system $(kubectl get pod -n elastic-system -l app=elasticsearch-master -o jsonpath='{.items[0].metadata.name}') -- curl -s http://localhost:9200/_cluster/health 2>/dev/null | grep -q "green\|yellow"; then
    echo -e "${GREEN}✓${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗${NC}"
    ((FAILED++))
fi

echo ""
echo "================================"
echo " Validation Summary"
echo "================================"
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "================================"
    echo " Access Information"
    echo "================================"
    
    # Grafana
    GRAFANA_URL=$(kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$GRAFANA_URL" ]; then
        echo "Grafana: http://${GRAFANA_URL}"
    fi
    
    # Kibana
    KIBANA_URL=$(kubectl get svc kibana-kibana -n elastic-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$KIBANA_URL" ]; then
        echo "Kibana: http://${KIBANA_URL}:5601"
    fi
    
    # ArgoCD
    ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$ARGOCD_URL" ]; then
        echo "ArgoCD: https://${ARGOCD_URL}"
    fi
    
    # Frontend
    FRONTEND_URL=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$FRONTEND_URL" ]; then
        echo "Tax Calculator: http://${FRONTEND_URL}"
    fi
    
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Please review and fix issues.${NC}"
    echo ""
    echo "To debug failed components:"
    echo "  kubectl get pods --all-namespaces | grep -v Running"
    echo "  kubectl describe pod <pod-name> -n <namespace>"
    echo "  kubectl logs <pod-name> -n <namespace>"
    exit 1
fi
