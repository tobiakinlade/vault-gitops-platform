#!/bin/bash
set -e

# Master Deployment Script for Part 2
# Deploys all components in correct order

echo "========================================="
echo " Part 2: Master Deployment Script"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
DRY_RUN=${DRY_RUN:-false}
SKIP_ARGOCD=${SKIP_ARGOCD:-false}
SKIP_MONITORING=${SKIP_MONITORING:-false}
SKIP_LOGGING=${SKIP_LOGGING:-false}
SKIP_ELK=${SKIP_ELK:-false}

# Function to print step
print_step() {
    echo ""
    echo -e "${BLUE}==>${NC} ${YELLOW}$1${NC}"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}✗ kubectl is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ kubectl installed${NC}"
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}✗ helm is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ helm installed${NC}"
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Connected to Kubernetes cluster${NC}"
    
    # Check nodes
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    READY_COUNT=$(kubectl get nodes --no-headers | grep " Ready" | wc -l)
    echo -e "${GREEN}✓ Cluster has $READY_COUNT/$NODE_COUNT nodes ready${NC}"
    
    if [ "$READY_COUNT" -lt 3 ]; then
        echo -e "${YELLOW}⚠ Warning: Less than 3 nodes ready. Some components may not deploy correctly.${NC}"
    fi
}

# Function to deploy component
deploy_component() {
    SCRIPT=$1
    COMPONENT=$2
    SKIP_VAR=$3
    
    if [ "${!SKIP_VAR}" = "true" ]; then
        echo -e "${YELLOW}⊘ Skipping $COMPONENT (SKIP_$SKIP_VAR=true)${NC}"
        return 0
    fi
    
    print_step "Deploying $COMPONENT..."
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}[DRY RUN] Would execute: ./$SCRIPT${NC}"
        return 0
    fi
    
    if [ -f "./$SCRIPT" ]; then
        chmod +x "./$SCRIPT"
        if ./"$SCRIPT"; then
            echo -e "${GREEN}✓ $COMPONENT deployed successfully${NC}"
        else
            echo -e "${RED}✗ $COMPONENT deployment failed${NC}"
            echo ""
            echo "To retry manually:"
            echo "  ./$SCRIPT"
            echo ""
            read -p "Continue with remaining components? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        echo -e "${RED}✗ Script not found: $SCRIPT${NC}"
        exit 1
    fi
}

# Main deployment flow
main() {
    echo "This script will deploy:"
    echo "  1. Repository structure"
    echo "  2. Namespaces"
    echo "  3. ArgoCD (GitOps)"
    echo "  4. Observability (Prometheus, Grafana, Loki)"
    echo "  5. ELK Stack (Elasticsearch, Kibana, Fluentd)"
    echo ""
    
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}DRY RUN MODE - No actual changes will be made${NC}"
        echo ""
    fi
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # Start timer
    START_TIME=$(date +%s)
    
    # Check prerequisites
    check_prerequisites
    
    # Step 1: Repository setup
    print_step "Step 1: Setting up repository structure"
    if [ ! "$DRY_RUN" = "true" ]; then
        if [ -f "./setup-repository.sh" ]; then
            echo "Repository setup script found. Run manually if needed:"
            echo "  ./setup-repository.sh"
        fi
    fi
    
    # Step 2: Create namespaces
    print_step "Step 2: Creating namespaces"
    if [ ! "$DRY_RUN" = "true" ]; then
        if [ -f "namespaces.yaml" ]; then
            kubectl apply -f namespaces.yaml
            echo -e "${GREEN}✓ Namespaces created${NC}"
        fi
    fi
    
    # Step 3: Deploy ArgoCD
    deploy_component "deploy-argocd.sh" "ArgoCD" "SKIP_ARGOCD"
    
    # Step 4: Deploy Observability
    deploy_component "deploy-monitoring.sh" "Observability Stack" "SKIP_MONITORING"
    
    # Step 5: Deploy Logging
    if [ "$SKIP_ELK" = "false" ]; then
        deploy_component "deploy-logging.sh" "ELK Stack" "SKIP_ELK"
    else
        echo -e "${YELLOW}⊘ Skipping ELK Stack (SKIP_ELK=true)${NC}"
    fi
    
    # Step 6: Validate deployment
    print_step "Validating deployment..."
    if [ ! "$DRY_RUN" = "true" ]; then
        if [ -f "./validate-part2.sh" ]; then
            chmod +x "./validate-part2.sh"
            ./validate-part2.sh
        fi
    fi
    
    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo ""
    echo "========================================="
    echo -e " ${GREEN}Deployment Complete!${NC}"
    echo "========================================="
    echo "Duration: ${MINUTES}m ${SECONDS}s"
    echo ""
    
    print_step "Next Steps:"
    echo "1. Access Grafana and explore dashboards"
    echo "2. Access Kibana and create index patterns"
    echo "3. Configure ArgoCD applications"
    echo "4. Deploy security policies"
    echo "5. Set up backup with Velero"
    echo ""
    
    echo "Access URLs (if LoadBalancers are ready):"
    echo "  Grafana: kubectl get svc -n monitoring kube-prometheus-stack-grafana"
    echo "  Kibana: kubectl get svc -n elastic-system kibana-kibana"
    echo "  ArgoCD: kubectl get svc -n argocd argocd-server"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-argocd)
            SKIP_ARGOCD=true
            shift
            ;;
        --skip-monitoring)
            SKIP_MONITORING=true
            shift
            ;;
        --skip-elk)
            SKIP_ELK=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run          Show what would be deployed without deploying"
            echo "  --skip-argocd      Skip ArgoCD deployment"
            echo "  --skip-monitoring  Skip Observability stack"
            echo "  --skip-elk         Skip ELK stack"
            echo "  --help             Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main deployment
main
