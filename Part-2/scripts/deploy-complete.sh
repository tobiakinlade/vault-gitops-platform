#!/bin/bash
set -e

# Part 2 - Complete Deployment Script
# Deploys EVERYTHING: GitOps, Observability, Logging, Security, Operations, SRE

echo "============================================"
echo " Part 2: Complete Production Deployment"
echo "============================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Track time
START_TIME=$(date +%s)

# Configuration
DEPLOY_ARGOCD=${DEPLOY_ARGOCD:-true}
DEPLOY_MONITORING=${DEPLOY_MONITORING:-true}
DEPLOY_LOGGING=${DEPLOY_LOGGING:-true}
DEPLOY_ELK=${DEPLOY_ELK:-true}
DEPLOY_SECURITY=${DEPLOY_SECURITY:-true}
DEPLOY_OPERATIONS=${DEPLOY_OPERATIONS:-true}
DEPLOY_SRE=${DEPLOY_SRE:-true}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local MISSING=0
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}✗ kubectl not found${NC}"
        ((MISSING++))
    else
        echo -e "${GREEN}✓ kubectl installed${NC}"
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}✗ helm not found${NC}"
        ((MISSING++))
    else
        echo -e "${GREEN}✓ helm installed${NC}"
    fi
    
    # Check aws cli
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}✗ aws cli not found${NC}"
        ((MISSING++))
    else
        echo -e "${GREEN}✓ aws cli installed${NC}"
    fi
    
    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
        ((MISSING++))
    else
        echo -e "${GREEN}✓ Connected to cluster${NC}"
        CLUSTER_NAME=$(kubectl config current-context)
        echo "  Cluster: $CLUSTER_NAME"
    fi
    
    # Check nodes
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep " Ready" | wc -l)
    if [ "$READY_COUNT" -ge 3 ]; then
        echo -e "${GREEN}✓ $READY_COUNT/$NODE_COUNT nodes ready${NC}"
    else
        echo -e "${YELLOW}⚠ Only $READY_COUNT/$NODE_COUNT nodes ready (recommended: 3+)${NC}"
    fi
    
    if [ $MISSING -gt 0 ]; then
        echo ""
        echo -e "${RED}✗ $MISSING prerequisite(s) missing. Please install required tools.${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

deploy_component() {
    local SCRIPT=$1
    local NAME=$2
    local ENABLED=$3
    
    if [ "$ENABLED" != "true" ]; then
        echo -e "${YELLOW}⊘ Skipping $NAME${NC}"
        return 0
    fi
    
    print_header "Deploying: $NAME"
    
    if [ ! -f "./$SCRIPT" ]; then
        echo -e "${RED}✗ Script not found: $SCRIPT${NC}"
        return 1
    fi
    
    chmod +x "./$SCRIPT"
    
    if ./"$SCRIPT"; then
        echo -e "${GREEN}✓ $NAME deployed successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ $NAME deployment failed${NC}"
        echo ""
        read -p "Continue with remaining components? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 1
    fi
}

print_summary() {
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    local MINUTES=$((DURATION / 60))
    local SECONDS=$((DURATION % 60))
    
    print_header "Deployment Summary"
    
    echo "Duration: ${MINUTES}m ${SECONDS}s"
    echo ""
    echo "Components Deployed:"
    [ "$DEPLOY_ARGOCD" = "true" ] && echo "  ✓ ArgoCD (GitOps)"
    [ "$DEPLOY_MONITORING" = "true" ] && echo "  ✓ Observability (Prometheus, Grafana, Loki)"
    [ "$DEPLOY_ELK" = "true" ] && echo "  ✓ ELK Stack (Elasticsearch, Kibana, Fluentd)"
    [ "$DEPLOY_SECURITY" = "true" ] && echo "  ✓ Security (Network Policies, cert-manager, Falco)"
    [ "$DEPLOY_OPERATIONS" = "true" ] && echo "  ✓ Operations (Velero, HPA/VPA, Cluster Autoscaler)"
    [ "$DEPLOY_SRE" = "true" ] && echo "  ✓ SRE (SLI/SLO, Error Budgets, Dashboards)"
    echo ""
    
    print_header "Access Information"
    
    # Grafana
    GRAFANA_URL=$(kubectl get svc kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
    echo "Grafana:"
    echo "  URL: http://${GRAFANA_URL}"
    echo "  Username: admin"
    echo "  Password: admin123"
    echo "  Port-forward: kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80"
    echo ""
    
    # Kibana
    if [ "$DEPLOY_ELK" = "true" ]; then
        KIBANA_URL=$(kubectl get svc kibana-kibana -n elastic-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
        echo "Kibana:"
        echo "  URL: http://${KIBANA_URL}:5601"
        echo "  Port-forward: kubectl port-forward svc/kibana-kibana -n elastic-system 5601:5601"
        echo ""
    fi
    
    # ArgoCD
    if [ "$DEPLOY_ARGOCD" = "true" ]; then
        ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
        echo "ArgoCD:"
        echo "  URL: https://${ARGOCD_URL}"
        echo "  Username: admin"
        echo "  Password: (see argocd-credentials.txt)"
        echo "  Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
        echo ""
    fi
    
    # Application
    FRONTEND_URL=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
    echo "Tax Calculator Application:"
    echo "  URL: http://${FRONTEND_URL}"
    echo ""
    
    print_header "Next Steps"
    
    echo "1. Change Default Passwords:"
    echo "   - Grafana admin password"
    echo "   - ArgoCD admin password"
    echo ""
    echo "2. Configure Integrations:"
    echo "   - AlertManager (Slack, PagerDuty, email)"
    echo "   - Update cert-manager ClusterIssuer email"
    echo ""
    echo "3. Create Custom Dashboards:"
    echo "   - Application-specific metrics"
    echo "   - Business metrics"
    echo ""
    echo "4. Test Everything:"
    echo "   - Generate load on application"
    echo "   - Trigger test alerts"
    echo "   - Test backup/restore"
    echo "   - Test autoscaling"
    echo ""
    echo "5. Validate:"
    echo "   ./validate-part2.sh"
    echo ""
    
    echo "════════════════════════════════════════════"
    echo -e "${GREEN}✓ Part 2 Deployment Complete!${NC}"
    echo "════════════════════════════════════════════"
}

# Main execution
main() {
    echo "This will deploy a complete production-grade platform:"
    echo ""
    echo "  📦 GitOps (ArgoCD)               - ${DEPLOY_ARGOCD}"
    echo "  📊 Observability (P+G+L)         - ${DEPLOY_MONITORING}"
    echo "  📝 Enterprise Logging (ELK)      - ${DEPLOY_ELK}"
    echo "  🔒 Security (Policies+TLS+Falco) - ${DEPLOY_SECURITY}"
    echo "  ⚙️  Operations (Backup+Scaling)   - ${DEPLOY_OPERATIONS}"
    echo "  📈 SRE (SLI/SLO+Alerts)          - ${DEPLOY_SRE}"
    echo ""
    echo "Estimated time: 45-60 minutes"
    echo ""
    
    read -p "Proceed with deployment? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
    
    # Pre-flight checks
    check_prerequisites
    
    # Deploy components
    deploy_component "deploy-argocd.sh" "ArgoCD (GitOps)" "$DEPLOY_ARGOCD"
    deploy_component "deploy-monitoring.sh" "Observability Stack" "$DEPLOY_MONITORING"
    deploy_component "deploy-logging.sh" "ELK Stack" "$DEPLOY_ELK"
    deploy_component "deploy-security.sh" "Security Components" "$DEPLOY_SECURITY"
    deploy_component "deploy-operations.sh" "Operations Tools" "$DEPLOY_OPERATIONS"
    deploy_component "deploy-sre.sh" "SRE Components" "$DEPLOY_SRE"
    
    # Validate
    if [ -f "./validate-part2.sh" ]; then
        print_header "Validating Deployment"
        chmod +x "./validate-part2.sh"
        ./validate-part2.sh || echo "Validation completed with warnings"
    fi
    
    # Print summary
    print_summary
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-argocd)
            DEPLOY_ARGOCD=false
            shift
            ;;
        --skip-monitoring)
            DEPLOY_MONITORING=false
            shift
            ;;
        --skip-elk)
            DEPLOY_ELK=false
            shift
            ;;
        --skip-security)
            DEPLOY_SECURITY=false
            shift
            ;;
        --skip-operations)
            DEPLOY_OPERATIONS=false
            shift
            ;;
        --skip-sre)
            DEPLOY_SRE=false
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Deploy complete Part 2 infrastructure"
            echo ""
            echo "Options:"
            echo "  --skip-argocd       Skip ArgoCD deployment"
            echo "  --skip-monitoring   Skip Observability stack"
            echo "  --skip-elk          Skip ELK stack"
            echo "  --skip-security     Skip Security components"
            echo "  --skip-operations   Skip Operations tools"
            echo "  --skip-sre          Skip SRE components"
            echo "  --help              Show this help"
            echo ""
            echo "Environment Variables:"
            echo "  DEPLOY_ARGOCD=false       Disable ArgoCD"
            echo "  DEPLOY_MONITORING=false   Disable Monitoring"
            echo "  DEPLOY_ELK=false          Disable ELK"
            echo "  DEPLOY_SECURITY=false     Disable Security"
            echo "  DEPLOY_OPERATIONS=false   Disable Operations"
            echo "  DEPLOY_SRE=false          Disable SRE"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
    esac
done

# Run main
main
