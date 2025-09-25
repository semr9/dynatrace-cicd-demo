#!/bin/bash

# EKS Deployment Script for E-commerce Demo
# This script creates an EKS cluster and deploys the e-commerce application

set -e

# Configuration
CLUSTER_NAME="ecommerce-demo-cluster"
REGION="us-west-2"
NODE_GROUP_NAME="ecommerce-demo-nodes"
NODE_TYPE="t3.medium"
NODE_COUNT=3
NAMESPACE="ecommerce-demo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check if eksctl is installed
    if ! command -v eksctl &> /dev/null; then
        log_error "eksctl is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    log_info "All prerequisites met!"
}

# Create EKS cluster
create_eks_cluster() {
    log_info "Creating EKS cluster: $CLUSTER_NAME"
    
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $REGION \
        --nodegroup-name $NODE_GROUP_NAME \
        --node-type $NODE_TYPE \
        --nodes $NODE_COUNT \
        --nodes-min 2 \
        --nodes-max 5 \
        --managed \
        --with-oidc \
        --ssh-access \
        --ssh-public-key ~/.ssh/id_rsa.pub \
        --yes
    
    log_info "EKS cluster created successfully!"
}

# Update kubeconfig
update_kubeconfig() {
    log_info "Updating kubeconfig..."
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    log_info "Kubeconfig updated!"
}

# Install NGINX Ingress Controller
install_ingress_controller() {
    log_info "Installing NGINX Ingress Controller..."
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml
    
    log_info "Waiting for ingress controller to be ready..."
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=300s
    
    log_info "NGINX Ingress Controller installed!"
}

# Install Dynatrace Operator
install_dynatrace_operator() {
    log_info "Installing Dynatrace Operator..."
    
    # Create namespace first
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Dynatrace Operator
    kubectl apply -f https://github.com/Dynatrace/dynatrace-operator/releases/download/v0.12.0/dynatrace-operator.yaml
    
    log_info "Waiting for Dynatrace Operator to be ready..."
    kubectl wait --namespace dynatrace-system \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/name=dynatrace-operator \
        --timeout=300s
    
    log_info "Dynatrace Operator installed!"
}

# Deploy application
deploy_application() {
    log_info "Deploying e-commerce application..."
    
    # Apply Kubernetes manifests in order
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/postgres.yaml
    kubectl apply -f k8s/redis.yaml
    kubectl apply -f k8s/services.yaml
    kubectl apply -f k8s/deployments.yaml
    kubectl apply -f k8s/ingress.yaml
    
    log_info "Application deployed!"
}

# Wait for deployment to be ready
wait_for_deployment() {
    log_info "Waiting for all deployments to be ready..."
    
    deployments=("postgres" "redis" "api-gateway" "user-service" "product-service" "order-service" "payment-service" "frontend")
    
    for deployment in "${deployments[@]}"; do
        log_info "Waiting for deployment: $deployment"
        kubectl wait --namespace $NAMESPACE \
            --for=condition=available \
            --timeout=600s \
            deployment/$deployment
    done
    
    log_info "All deployments are ready!"
}

# Get application URLs
get_urls() {
    log_info "Getting application URLs..."
    
    # Get LoadBalancer URL
    EXTERNAL_IP=$(kubectl get service ecommerce-loadbalancer --namespace $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ -z "$EXTERNAL_IP" ]; then
        log_warn "LoadBalancer external IP not available yet. Run 'kubectl get services --namespace $NAMESPACE' to check status."
    else
        log_info "Application is available at: http://$EXTERNAL_IP"
    fi
    
    # Get Ingress URL
    INGRESS_HOST=$(kubectl get ingress ecommerce-ingress --namespace $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ -z "$INGRESS_HOST" ]; then
        log_warn "Ingress host not available yet. Run 'kubectl get ingress --namespace $NAMESPACE' to check status."
    else
        log_info "Application is also available via Ingress at: http://$INGRESS_HOST"
    fi
}

# Run health checks
run_health_checks() {
    log_info "Running health checks..."
    
    # Wait a bit for services to stabilize
    sleep 30
    
    # Check if all pods are running
    RUNNING_PODS=$(kubectl get pods --namespace $NAMESPACE --field-selector=status.phase=Running --no-headers | wc -l)
    TOTAL_PODS=$(kubectl get pods --namespace $NAMESPACE --no-headers | wc -l)
    
    log_info "Running pods: $RUNNING_PODS/$TOTAL_PODS"
    
    if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
        log_info "All pods are running!"
    else
        log_warn "Some pods are not running. Check with 'kubectl get pods --namespace $NAMESPACE'"
    fi
    
    # Check service endpoints
    kubectl get endpoints --namespace $NAMESPACE
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    eksctl delete cluster --name $CLUSTER_NAME --region $REGION --yes
    log_info "Cleanup completed!"
}

# Main deployment function
main() {
    log_info "Starting EKS deployment for E-commerce Demo..."
    
    check_prerequisites
    create_eks_cluster
    update_kubeconfig
    install_ingress_controller
    install_dynatrace_operator
    deploy_application
    wait_for_deployment
    run_health_checks
    get_urls
    
    log_info "Deployment completed successfully!"
    log_info "You can now access your application and start testing Dynatrace CI/CD automation features."
    
    # Display useful commands
    echo ""
    log_info "Useful commands:"
    echo "  View pods: kubectl get pods --namespace $NAMESPACE"
    echo "  View services: kubectl get services --namespace $NAMESPACE"
    echo "  View logs: kubectl logs -f deployment/api-gateway --namespace $NAMESPACE"
    echo "  Delete cluster: $0 cleanup"
}

# Handle command line arguments
case "${1:-deploy}" in
    deploy)
        main
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "Usage: $0 [deploy|cleanup]"
        echo "  deploy  - Deploy the application (default)"
        echo "  cleanup - Clean up the EKS cluster"
        exit 1
        ;;
esac
