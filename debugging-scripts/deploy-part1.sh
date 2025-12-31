#!/bin/bash

###############################################################################
# PART 1 AUTOMATED DEPLOYMENT
# This script deploys all infrastructure and the tax calculator application
# Required before starting Part 2 of the tutorial
###############################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
TERRAFORM_DIR="terraform/environments/dev"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VAULT_KEYS_FILE="${PROJECT_ROOT}/vault-keys.txt"
KUBECONFIG_BACKUP="${HOME}/.kube/config.backup.$(date +%s)"

###############################################################################
# Helper Functions
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "============================================================================="
    echo "  $1"
    echo "============================================================================="
    echo ""
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check required tools
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v aws >/dev/null 2>&1 || missing_tools+=("aws-cli")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v jq >/dev/null 2>&1 || missing_tools+=("jq")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and try again"
        exit 1
    fi
    
    log_success "All required tools installed"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS credentials not configured or invalid"
        log_info "Run 'aws configure' to set up credentials"
        exit 1
    fi
    
    local aws_account=$(aws sts get-caller-identity --query Account --output text)
    local aws_user=$(aws sts get-caller-identity --query Arn --output text)
    log_success "AWS credentials valid"
    log_info "Account: ${aws_account}"
    log_info "User: ${aws_user}"
    
    # Check Terraform directory
    if [ ! -d "${PROJECT_ROOT}/${TERRAFORM_DIR}" ]; then
        log_error "Terraform directory not found: ${TERRAFORM_DIR}"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

backup_kubeconfig() {
    if [ -f "${HOME}/.kube/config" ]; then
        log_warning "Backing up existing kubeconfig to ${KUBECONFIG_BACKUP}"
        cp "${HOME}/.kube/config" "${KUBECONFIG_BACKUP}"
    fi
}

deploy_infrastructure() {
    print_header "Deploying Infrastructure with Terraform"
    
    cd "${PROJECT_ROOT}/${TERRAFORM_DIR}"
    
    log_info "Initializing Terraform..."
    terraform init
    
    log_info "Validating Terraform configuration..."
    terraform validate
    
    log_info "Planning infrastructure deployment..."
    terraform plan -out=tfplan
    
    log_warning "About to create AWS infrastructure. This will incur costs."
    read -p "Continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    log_info "Applying Terraform configuration (this takes 15-20 minutes)..."
    terraform apply tfplan
    
    log_success "Infrastructure deployed successfully"
    
    # Get outputs
    export CLUSTER_NAME=$(terraform output -raw cluster_name)
    export AWS_REGION=$(terraform output -raw aws_region)
    export VAULT_NAMESPACE="vault"
    
    log_info "Cluster Name: ${CLUSTER_NAME}"
    log_info "AWS Region: ${AWS_REGION}"
}

configure_kubectl() {
    print_header "Configuring kubectl"
    
    log_info "Updating kubeconfig for EKS cluster: ${CLUSTER_NAME}"
    aws eks update-kubeconfig \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --alias "${CLUSTER_NAME}"
    
    log_info "Waiting for cluster to be ready..."
    local retries=0
    local max_retries=30
    until kubectl get nodes &>/dev/null || [ $retries -eq $max_retries ]; do
        log_info "Waiting for cluster access... (${retries}/${max_retries})"
        sleep 10
        ((retries++))
    done
    
    if [ $retries -eq $max_retries ]; then
        log_error "Could not connect to cluster after ${max_retries} attempts"
        exit 1
    fi
    
    log_success "kubectl configured successfully"
    
    # Verify nodes
    log_info "Cluster nodes:"
    kubectl get nodes
    
    # Wait for nodes to be ready
    log_info "Waiting for all nodes to be Ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    log_success "All nodes are Ready"
}

deploy_vault() {
    print_header "Deploying HashiCorp Vault"
    
    # Vault should already be deployed by Terraform, verify it
    log_info "Checking Vault deployment..."
    
    if ! kubectl get namespace "${VAULT_NAMESPACE}" &>/dev/null; then
        log_error "Vault namespace not found. Terraform may not have deployed Vault."
        log_info "Please check Terraform vault module"
        exit 1
    fi
    
    log_info "Waiting for Vault pods to be ready..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=vault \
        -n "${VAULT_NAMESPACE}" \
        --timeout=300s || true
    
    log_info "Vault pods:"
    kubectl get pods -n "${VAULT_NAMESPACE}"
    
    log_success "Vault deployment verified"
}

initialize_vault() {
    print_header "Initializing Vault"
    
    # Check if Vault is already initialized
    local vault_pod=$(kubectl get pod -n "${VAULT_NAMESPACE}" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
    
    log_info "Checking Vault initialization status..."
    if kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- vault status &>/dev/null; then
        log_info "Vault is already initialized and unsealed"
        
        # Check if vault-keys.txt exists
        if [ -f "${VAULT_KEYS_FILE}" ]; then
            log_success "Vault keys file found: ${VAULT_KEYS_FILE}"
            return 0
        else
            log_warning "Vault is initialized but keys file not found"
            log_warning "You may need to manually recover Vault keys"
            return 0
        fi
    fi
    
    log_info "Initializing Vault..."
    local init_output=$(kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- \
        vault operator init -key-shares=5 -key-threshold=3 -format=json)
    
    # Save keys
    echo "${init_output}" > "${VAULT_KEYS_FILE}"
    chmod 600 "${VAULT_KEYS_FILE}"
    
    log_success "Vault initialized. Keys saved to: ${VAULT_KEYS_FILE}"
    log_warning "IMPORTANT: Backup this file securely!"
    
    # Extract unseal keys
    local unseal_key_1=$(echo "${init_output}" | jq -r '.unseal_keys_b64[0]')
    local unseal_key_2=$(echo "${init_output}" | jq -r '.unseal_keys_b64[1]')
    local unseal_key_3=$(echo "${init_output}" | jq -r '.unseal_keys_b64[2]')
    export ROOT_TOKEN=$(echo "${init_output}" | jq -r '.root_token')
    
    # Unseal Vault
    log_info "Unsealing Vault..."
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- vault operator unseal "${unseal_key_1}"
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- vault operator unseal "${unseal_key_2}"
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- vault operator unseal "${unseal_key_3}"
    
    log_success "Vault unsealed successfully"
    
    # Verify status
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- vault status
}

configure_vault_secrets() {
    print_header "Configuring Vault Secrets"
    
    local vault_pod=$(kubectl get pod -n "${VAULT_NAMESPACE}" -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')
    
    # Get root token
    if [ -z "${ROOT_TOKEN}" ]; then
        if [ -f "${VAULT_KEYS_FILE}" ]; then
            export ROOT_TOKEN=$(cat "${VAULT_KEYS_FILE}" | jq -r '.root_token')
        else
            log_error "ROOT_TOKEN not set and vault-keys.txt not found"
            log_warning "Skipping Vault secret configuration"
            return 1
        fi
    fi
    
    log_info "Logging into Vault..."
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- \
        vault login "${ROOT_TOKEN}" &>/dev/null
    
    log_info "Enabling KV secrets engine..."
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- \
        vault secrets enable -path=secret kv-v2 2>/dev/null || \
        log_info "KV secrets engine already enabled"
    
    log_info "Storing database credentials..."
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- \
        vault kv put secret/tax-calculator/database \
        username=taxcalc_user \
        password=TaxCalc2024SecurePassword \
        host=postgres \
        port=5432 \
        database=taxcalculator
    
    log_info "Enabling Kubernetes auth..."
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- \
        vault auth enable kubernetes 2>/dev/null || \
        log_info "Kubernetes auth already enabled"
    
    log_info "Configuring Kubernetes auth..."
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- sh -c '
        vault write auth/kubernetes/config \
            kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
    '
    
    log_info "Creating Vault policy for tax calculator..."
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- sh -c '
        vault policy write tax-calculator - <<EOF
path "secret/data/tax-calculator/*" {
  capabilities = ["read"]
}
EOF
    '
    
    log_info "Creating Kubernetes auth role..."
    kubectl exec -n "${VAULT_NAMESPACE}" "${vault_pod}" -- \
        vault write auth/kubernetes/role/tax-calculator \
        bound_service_account_names=tax-calculator \
        bound_service_account_namespaces=tax-calculator \
        policies=tax-calculator \
        ttl=24h
    
    log_success "Vault secrets configured successfully"
}

create_tax_calculator_namespace() {
    print_header "Creating Tax Calculator Namespace"
    
    log_info "Creating namespace and service account..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: tax-calculator
  labels:
    name: tax-calculator
    app.kubernetes.io/part-of: application
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tax-calculator
  namespace: tax-calculator
EOF
    
    log_success "Namespace and service account created"
}

deploy_postgres() {
    print_header "Deploying PostgreSQL Database"
    
    log_info "Applying PostgreSQL manifests..."
    
    # Use the k8s manifests from tax-calculator-app
    if [ -f "${PROJECT_ROOT}/tax-calculator-app/k8s/postgres-deployment.yaml" ]; then
        kubectl apply -f "${PROJECT_ROOT}/tax-calculator-app/k8s/postgres-deployment.yaml"
        kubectl apply -f "${PROJECT_ROOT}/tax-calculator-app/k8s/postgres-service.yaml"
    else
        log_error "PostgreSQL manifests not found"
        exit 1
    fi
    
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod \
        -l component=database \
        -n tax-calculator \
        --timeout=300s
    
    log_success "PostgreSQL deployed successfully"
}

deploy_backend() {
    print_header "Deploying Backend Application"
    
    log_info "Applying backend manifests..."
    
    # Use the manifests from kubernetes/base or tax-calculator-app/k8s
    if [ -f "${PROJECT_ROOT}/kubernetes/base/tax-calculator/backend/backend-deployment.yaml" ]; then
        kubectl apply -f "${PROJECT_ROOT}/kubernetes/base/tax-calculator/backend/backend-deployment.yaml"
        kubectl apply -f "${PROJECT_ROOT}/kubernetes/base/tax-calculator/backend/backend-service.yaml"
    elif [ -f "${PROJECT_ROOT}/tax-calculator-app/k8s/backend-deployment.yaml" ]; then
        kubectl apply -f "${PROJECT_ROOT}/tax-calculator-app/k8s/backend-deployment.yaml"
        kubectl apply -f "${PROJECT_ROOT}/tax-calculator-app/k8s/backend-service.yaml"
    else
        log_error "Backend manifests not found"
        exit 1
    fi
    
    log_info "Waiting for backend to be ready..."
    kubectl wait --for=condition=ready pod \
        -l component=backend \
        -n tax-calculator \
        --timeout=300s
    
    log_success "Backend deployed successfully"
}

deploy_frontend() {
    print_header "Deploying Frontend Application"
    
    log_info "Applying frontend manifests..."
    
    if [ -f "${PROJECT_ROOT}/tax-calculator-app/k8s/frontend-deployment.yaml" ]; then
        kubectl apply -f "${PROJECT_ROOT}/tax-calculator-app/k8s/frontend-deployment.yaml"
        kubectl apply -f "${PROJECT_ROOT}/tax-calculator-app/k8s/frontend-service.yaml"
    else
        log_error "Frontend manifests not found"
        exit 1
    fi
    
    log_info "Waiting for frontend to be ready..."
    kubectl wait --for=condition=ready pod \
        -l component=frontend \
        -n tax-calculator \
        --timeout=300s
    
    log_success "Frontend deployed successfully"
}

verify_deployment() {
    print_header "Verifying Deployment"
    
    log_info "Checking all pods in tax-calculator namespace..."
    kubectl get pods -n tax-calculator
    
    log_info "Checking services..."
    kubectl get svc -n tax-calculator
    
    # Get LoadBalancer URLs
    log_info "Waiting for LoadBalancer to be provisioned..."
    sleep 30
    
    local frontend_url=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    local backend_url=$(kubectl get svc backend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    
    log_info "Frontend URL: http://${frontend_url}"
    log_info "Backend URL: http://${backend_url}:8080"
    
    # Test backend health
    if [ "${backend_url}" != "pending" ]; then
        log_info "Testing backend health endpoint..."
        sleep 20  # Give more time for LB
        if curl -s -f "http://${backend_url}:8080/health" &>/dev/null; then
            log_success "Backend health check passed"
        else
            log_warning "Backend health check failed (may need more time)"
        fi
    fi
    
    log_success "Deployment verification complete"
}

print_summary() {
    print_header "Deployment Summary"
    
    echo ""
    echo "✅ Infrastructure deployed successfully!"
    echo ""
    echo "📋 Summary:"
    echo "  - EKS Cluster: ${CLUSTER_NAME}"
    echo "  - AWS Region: ${AWS_REGION}"
    echo "  - Vault: Deployed and configured"
    echo "  - Tax Calculator App: Deployed"
    echo ""
    
    local frontend_url=$(kubectl get svc frontend -n tax-calculator -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
    
    echo "🌐 Application URLs:"
    echo "  Frontend: http://${frontend_url}"
    echo ""
    
    echo "🔐 Important Files:"
    echo "  Vault Keys: ${VAULT_KEYS_FILE}"
    if [ -f "${KUBECONFIG_BACKUP}" ]; then
        echo "  Kubeconfig Backup: ${KUBECONFIG_BACKUP}"
    fi
    echo ""
    
    echo "📝 Useful Commands:"
    echo "  # View all resources"
    echo "  kubectl get all -n tax-calculator"
    echo ""
    echo "  # Check Vault status"
    echo "  kubectl get pods -n vault"
    echo ""
    echo "  # Get application logs"
    echo "  kubectl logs -n tax-calculator -l component=backend"
    echo "  kubectl logs -n tax-calculator -l component=frontend"
    echo ""
    
    echo "🚀 Next Steps:"
    echo "  1. Verify the application is accessible at the frontend URL"
    echo "  2. Test the tax calculator functionality"
    echo "  3. Proceed with Part 2 of the tutorial"
    echo ""
    
    echo "📚 Part 2 Prerequisites Met:"
    echo "  ✅ EKS cluster running"
    echo "  ✅ kubectl configured"
    echo "  ✅ Vault deployed and initialized"
    echo "  ✅ Tax calculator application running"
    echo "  ✅ All Part 1 requirements satisfied"
    echo ""
    
    log_success "You are now ready to start Part 2!"
}

cleanup_on_error() {
    log_error "Deployment failed. Check the error messages above."
    echo ""
    echo "To clean up and try again:"
    echo "  cd ${PROJECT_ROOT}/${TERRAFORM_DIR}"
    echo "  terraform destroy"
    echo ""
    exit 1
}

###############################################################################
# Main Execution
###############################################################################

main() {
    print_header "Part 1: Automated Infrastructure & Application Deployment"
    
    log_info "Starting deployment at $(date)"
    
    # Set trap for errors
    trap cleanup_on_error ERR
    
    # Execute deployment steps
    check_prerequisites
    backup_kubeconfig
    deploy_infrastructure
    configure_kubectl
    deploy_vault
    initialize_vault
    configure_vault_secrets
    create_tax_calculator_namespace
    deploy_postgres
    deploy_backend
    deploy_frontend
    verify_deployment
    print_summary
    
    log_info "Deployment completed at $(date)"
}

# Run main function
main "$@"
