#!/bin/bash

###############################################################################
# PART 1 VERIFICATION SCRIPT
# This script verifies that Part 1 is deployed correctly and ready for Part 2
###############################################################################

set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo ""
    echo "============================================================================="
    echo "  $1"
    echo "============================================================================="
    echo ""
}

check() {
    local name=$1
    local command=$2
    local severity=${3:-error}  # error or warning
    
    echo -n "  Checking $name... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
        return 0
    else
        if [ "$severity" == "warning" ]; then
            echo -e "${YELLOW}⚠${NC}"
            ((WARNINGS++))
        else
            echo -e "${RED}✗${NC}"
            ((FAILED++))
        fi
        return 1
    fi
}

check_with_output() {
    local name=$1
    local command=$2
    local expected=$3
    
    echo -n "  Checking $name... "
    
    local output=$(eval "$command" 2>/dev/null)
    
    if [ "$output" == "$expected" ]; then
        echo -e "${GREEN}✓${NC} ($output)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} (got: $output, expected: $expected)"
        ((FAILED++))
        return 1
    fi
}

###############################################################################
# Verification Functions
###############################################################################

verify_prerequisites() {
    print_header "Prerequisites"
    
    check "kubectl installed" "command -v kubectl"
    check "aws-cli installed" "command -v aws"
    check "helm installed" "command -v helm"
    check "jq installed" "command -v jq"
}

verify_aws_connection() {
    print_header "AWS Connection"
    
    check "AWS credentials configured" "aws sts get-caller-identity"
    
    if aws sts get-caller-identity &>/dev/null; then
        local account=$(aws sts get-caller-identity --query Account --output text)
        local user=$(aws sts get-caller-identity --query Arn --output text | awk -F'/' '{print $NF}')
        echo "  Account: $account"
        echo "  User: $user"
    fi
}

verify_cluster() {
    print_header "EKS Cluster"
    
    check "Cluster accessible" "kubectl cluster-info"
    
    if kubectl cluster-info &>/dev/null; then
        local cluster_name=$(kubectl config current-context)
        echo "  Cluster: $cluster_name"
    fi
    
    check "Nodes are Ready" "kubectl get nodes --no-headers | grep -q Ready"
    
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$node_count" -eq 3 ]; then
        echo -e "  Node count: ${GREEN}✓${NC} ($node_count/3)"
        ((PASSED++))
    else
        echo -e "  Node count: ${RED}✗${NC} ($node_count/3 expected)"
        ((FAILED++))
    fi
    
    echo ""
    echo "  Nodes:"
    kubectl get nodes 2>/dev/null | sed 's/^/    /'
}

verify_vault() {
    print_header "HashiCorp Vault"
    
    check "Vault namespace exists" "kubectl get namespace vault"
    check "Vault pods running" "kubectl get pods -n vault -l app.kubernetes.io/name=vault --no-headers | grep -q Running"
    
    local vault_pod=$(kubectl get pod -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -n "$vault_pod" ]; then
        check "Vault is initialized" "kubectl exec -n vault $vault_pod -- vault status | grep -q 'Initialized.*true'"
        check "Vault is unsealed" "kubectl exec -n vault $vault_pod -- vault status | grep -q 'Sealed.*false'"
        
        echo ""
        echo "  Vault Status:"
        kubectl exec -n vault "$vault_pod" -- vault status 2>/dev/null | sed 's/^/    /'
    else
        echo -e "  ${RED}✗${NC} Cannot find Vault pod"
        ((FAILED++))
    fi
    
    # Check vault-keys.txt
    if [ -f "vault-keys.txt" ]; then
        echo -e "  vault-keys.txt: ${GREEN}✓${NC} Found"
        ((PASSED++))
    else
        echo -e "  vault-keys.txt: ${YELLOW}⚠${NC} Not found (may need for Vault operations)"
        ((WARNINGS++))
    fi
}

verify_application() {
    print_header "Tax Calculator Application"
    
    check "tax-calculator namespace exists" "kubectl get namespace tax-calculator"
    check "PostgreSQL running" "kubectl get pods -n tax-calculator -l component=database --no-headers | grep -q Running"
    check "Backend running" "kubectl get pods -n tax-calculator -l component=backend --no-headers | grep -q Running"
    check "Frontend running" "kubectl get pods -n tax-calculator -l component=frontend --no-headers | grep -q Running"
    
    echo ""
    echo "  Application Pods:"
    kubectl get pods -n tax-calculator 2>/dev/null | sed 's/^/    /'
    
    echo ""
    echo "  Services:"
    kubectl get svc -n tax-calculator 2>/dev/null | sed 's/^/    /'
}

verify_networking() {
    print_header "Networking"
    
    check "Backend service exists" "kubectl get svc backend -n tax-calculator"
    check "Frontend service exists" "kubectl get svc frontend -n tax-calculator"
    
    local backend_type=$(kubectl get svc backend -n tax-calculator -o jsonpath='{.spec.type}' 2>/dev/null)
    local frontend_type=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.spec.type}' 2>/dev/null)
    
    if [ "$backend_type" == "LoadBalancer" ] || [ "$backend_type" == "NodePort" ]; then
        echo -e "  Backend service type: ${GREEN}✓${NC} ($backend_type)"
        ((PASSED++))
    else
        echo -e "  Backend service type: ${YELLOW}⚠${NC} ($backend_type)"
        ((WARNINGS++))
    fi
    
    if [ "$frontend_type" == "LoadBalancer" ] || [ "$frontend_type" == "NodePort" ]; then
        echo -e "  Frontend service type: ${GREEN}✓${NC} ($frontend_type)"
        ((PASSED++))
    else
        echo -e "  Frontend service type: ${YELLOW}⚠${NC} ($frontend_type)"
        ((WARNINGS++))
    fi
    
    # Check LoadBalancer URLs
    echo ""
    local frontend_url=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    local backend_url=$(kubectl get svc backend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$frontend_url" ]; then
        echo -e "  Frontend URL: ${GREEN}http://${frontend_url}${NC}"
    else
        echo -e "  Frontend URL: ${YELLOW}Pending...${NC}"
    fi
    
    if [ -n "$backend_url" ]; then
        echo -e "  Backend URL: ${GREEN}http://${backend_url}:8080${NC}"
    else
        echo -e "  Backend URL: ${YELLOW}Pending...${NC}"
    fi
}

verify_health() {
    print_header "Application Health"
    
    local backend_url=$(kubectl get svc backend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    
    if [ -n "$backend_url" ]; then
        echo "  Testing backend health endpoint..."
        if curl -s -f "http://${backend_url}:8080/health" &>/dev/null; then
            echo -e "  Backend health: ${GREEN}✓${NC} Responding"
            ((PASSED++))
        else
            echo -e "  Backend health: ${YELLOW}⚠${NC} Not responding (may need more time)"
            ((WARNINGS++))
        fi
    else
        echo -e "  Backend health: ${YELLOW}⚠${NC} Cannot test (LoadBalancer pending)"
        ((WARNINGS++))
    fi
}

verify_storage() {
    print_header "Storage"
    
    check "Storage class exists" "kubectl get storageclass gp2 || kubectl get storageclass gp3"
    check "EBS CSI driver installed" "kubectl get deployment -n kube-system ebs-csi-controller" warning
    
    local pvc_count=$(kubectl get pvc -n tax-calculator --no-headers 2>/dev/null | wc -l)
    if [ "$pvc_count" -gt 0 ]; then
        echo -e "  PVCs in tax-calculator: ${GREEN}✓${NC} ($pvc_count found)"
        ((PASSED++))
        kubectl get pvc -n tax-calculator 2>/dev/null | sed 's/^/    /'
    else
        echo -e "  PVCs in tax-calculator: ${YELLOW}⚠${NC} (none found)"
        ((WARNINGS++))
    fi
}

verify_part2_prerequisites() {
    print_header "Part 2 Prerequisites"
    
    echo "  Checking if ready for Part 2..."
    echo ""
    
    local ready=true
    
    # Must have
    if ! kubectl cluster-info &>/dev/null; then
        echo -e "  ${RED}✗${NC} Cluster not accessible"
        ready=false
    else
        echo -e "  ${GREEN}✓${NC} Cluster accessible"
    fi
    
    if ! kubectl get namespace tax-calculator &>/dev/null; then
        echo -e "  ${RED}✗${NC} tax-calculator namespace missing"
        ready=false
    else
        echo -e "  ${GREEN}✓${NC} tax-calculator namespace exists"
    fi
    
    if ! kubectl get pods -n tax-calculator -l component=backend --no-headers 2>/dev/null | grep -q Running; then
        echo -e "  ${RED}✗${NC} Backend not running"
        ready=false
    else
        echo -e "  ${GREEN}✓${NC} Backend running"
    fi
    
    if ! kubectl get pods -n vault -l app.kubernetes.io/name=vault --no-headers 2>/dev/null | grep -q Running; then
        echo -e "  ${RED}✗${NC} Vault not running"
        ready=false
    else
        echo -e "  ${GREEN}✓${NC} Vault running"
    fi
    
    # Should have
    if ! helm version &>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Helm not installed (needed for Part 2)"
    else
        echo -e "  ${GREEN}✓${NC} Helm available"
    fi
    
    echo ""
    if [ "$ready" = true ]; then
        echo -e "  ${GREEN}✓ Ready for Part 2!${NC}"
    else
        echo -e "  ${RED}✗ Not ready for Part 2 - fix issues above${NC}"
    fi
}

print_summary() {
    print_header "Verification Summary"
    
    local total=$((PASSED + FAILED + WARNINGS))
    
    echo ""
    echo "  Results:"
    echo -e "    ${GREEN}Passed:${NC}   $PASSED"
    echo -e "    ${RED}Failed:${NC}   $FAILED"
    echo -e "    ${YELLOW}Warnings:${NC} $WARNINGS"
    echo "    ─────────────"
    echo "    Total:    $total"
    echo ""
    
    if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${GREEN}✓ All checks passed! Ready for Part 2!${NC}"
        echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  Next steps:"
        echo "    1. Review PART2-COMPLETE-FINAL.md"
        echo "    2. Start with Part 1: Foundation Setup"
        echo "    3. Follow the tutorial step-by-step"
        echo ""
        return 0
    elif [ $FAILED -eq 0 ]; then
        echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${YELLOW}⚠ All critical checks passed with some warnings${NC}"
        echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  You can proceed with Part 2, but review warnings above"
        echo ""
        return 0
    else
        echo -e "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${RED}✗ Some checks failed - please fix before Part 2${NC}"
        echo -e "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "  To fix:"
        echo "    1. Review failed checks above"
        echo "    2. Check deployment logs"
        echo "    3. Try redeploying: ./deploy-part1.sh"
        echo ""
        return 1
    fi
}

###############################################################################
# Main Execution
###############################################################################

main() {
    echo ""
    echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo "┃                                                                    ┃"
    echo "┃             PART 1 VERIFICATION - PRE-PART 2 CHECK                ┃"
    echo "┃                                                                    ┃"
    echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    
    verify_prerequisites
    verify_aws_connection
    verify_cluster
    verify_vault
    verify_application
    verify_networking
    verify_health
    verify_storage
    verify_part2_prerequisites
    print_summary
    
    # Return appropriate exit code
    if [ $FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main
main "$@"
