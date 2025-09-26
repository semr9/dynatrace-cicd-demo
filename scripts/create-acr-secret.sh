#!/bin/bash

# Create ACR Secret Script for Dynatrace CI/CD Demo
# This script creates the Kubernetes secret needed to pull images from Azure Container Registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load configuration
if [ -f "azure/config.yaml" ]; then
    source <(sed -n 's/^\([^:]*\): *\(.*\)$/\1=\2/p' azure/config.yaml)
else
    print_error "Configuration file azure/config.yaml not found!"
    exit 1
fi

# Set default values if not provided
resourceGroup=${resourceGroup:-"dynatrace-cicd-rg"}
acrName=${acrName:-"dynatracecicdacr"}
appNamespace=${appNamespace:-"dynatrace-cicd"}

print_status "Creating ACR secret for image pulling..."

# Check if Azure CLI is logged in
if ! az account show &> /dev/null; then
    print_error "Azure CLI not logged in. Please run 'az login' first."
    exit 1
fi

# Check if ACR exists
if ! az acr show --name "$acrName" --resource-group "$resourceGroup" &> /dev/null; then
    print_error "ACR '$acrName' not found in resource group '$resourceGroup'"
    exit 1
fi

# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name "$acrName" --resource-group "$resourceGroup" --query loginServer --output tsv)
print_status "ACR Login Server: $ACR_LOGIN_SERVER"

# Check if namespace exists
if ! kubectl get namespace "$appNamespace" &> /dev/null; then
    print_warning "Namespace '$appNamespace' does not exist. Creating it..."
    kubectl create namespace "$appNamespace"
fi

# Delete existing secret if it exists
if kubectl get secret acr-secret -n "$appNamespace" &> /dev/null; then
    print_warning "Secret 'acr-secret' already exists. Deleting it..."
    kubectl delete secret acr-secret -n "$appNamespace"
fi

# Create the ACR secret
print_status "Creating ACR secret..."
kubectl create secret docker-registry acr-secret \
    --namespace "$appNamespace" \
    --docker-server="$ACR_LOGIN_SERVER" \
    --docker-username="$acrName" \
    --docker-password="$(az acr credential show --name "$acrName" --query passwords[0].value --output tsv)"

print_success "ACR secret created successfully!"
print_status "Secret details:"
kubectl describe secret acr-secret -n "$appNamespace"

print_success "ACR secret is ready for use in deployments!"
