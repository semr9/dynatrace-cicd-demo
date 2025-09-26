#!/bin/bash

# Azure Setup Script for Dynatrace CI/CD Demo
# This script helps you get started with Azure deployment

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

# Check if running on Windows
check_platform() {
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        print_warning "You are running on Windows. This script is designed for Linux/macOS."
        print_status "For Windows, please use PowerShell or WSL."
        print_status "You can also run the deployment directly on your Azure VM."
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed."
        print_status "Install it with: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
        exit 1
    fi
    
    # Check if logged in
    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure."
        print_status "Run: az login"
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed."
        print_status "Install it with: sudo apt-get update && sudo apt-get install docker.io"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed."
        print_status "Install it with: curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        exit 1
    fi
    
    print_success "All prerequisites are met"
}

# Display current Azure account
show_azure_account() {
    print_status "Current Azure account:"
    az account show --query "{subscriptionId: id, name: name, tenantId: tenantId}" --output table
    echo ""
}

# Check configuration
check_config() {
    if [ ! -f "azure/config.yaml" ]; then
        print_error "Configuration file azure/config.yaml not found"
        exit 1
    fi
    
    print_status "Current configuration:"
    echo "----------------------------------------"
    cat azure/config.yaml
    echo "----------------------------------------"
    echo ""
    
    print_warning "Please review the configuration above."
    print_status "Make sure to update the Dynatrace values in azure/config.yaml before proceeding."
    echo ""
}

# Show deployment options
show_deployment_options() {
    print_status "Deployment Options:"
    echo ""
    echo "1. Quick Deployment (Recommended)"
    echo "   ./scripts/azure-quick-deploy.sh"
    echo "   - Interactive step-by-step deployment"
    echo "   - Allows you to review each step"
    echo ""
    echo "2. Automated Deployment"
    echo "   ./scripts/azure-deploy.sh"
    echo "   - Fully automated deployment"
    echo "   - Runs all steps without interaction"
    echo ""
    echo "3. Manual Deployment"
    echo "   - Follow the instructions in README.md"
    echo "   - Full control over each step"
    echo ""
}

# Show cost estimation
show_cost_estimation() {
    print_status "Estimated Azure Costs (per month) - TESTING OPTIMIZED:"
    echo ""
    echo "Resource Group: Free"
    echo "Azure Container Registry (Basic): ~$5"
    echo "Azure Database for PostgreSQL (B_Gen5_1): ~$25"
    echo "Azure Kubernetes Service (1x Standard_B1s): ~$15"
    echo "Load Balancer: ~$20"
    echo "Total: ~$65/month (40% savings!)"
    echo ""
    print_warning "Costs may vary based on usage and region."
    print_status "Remember to delete resources when done to avoid charges."
    print_status "This configuration is optimized for testing purposes."
    echo ""
}

# Show next steps
show_next_steps() {
    print_status "Next Steps:"
    echo ""
    echo "1. Update azure/config.yaml with your Dynatrace values"
    echo "2. Choose your deployment method:"
    echo "   - Quick: ./scripts/azure-quick-deploy.sh"
    echo "   - Automated: ./scripts/azure-deploy.sh"
    echo "3. Monitor the deployment progress"
    echo "4. Access your application once deployed"
    echo "5. Configure Dynatrace monitoring"
    echo ""
    print_success "Ready to deploy!"
}

# Main function
main() {
    echo "=========================================="
    echo "  Azure Setup for Dynatrace CI/CD Demo"
    echo "=========================================="
    echo ""
    
    check_platform
    check_prerequisites
    show_azure_account
    check_config
    show_deployment_options
    show_cost_estimation
    show_next_steps
}

# Run main function
main "$@"
