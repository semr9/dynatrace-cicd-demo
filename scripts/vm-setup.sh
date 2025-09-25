#!/bin/bash

# Azure VM Setup Script for Dynatrace CI/CD Demo
# This script installs all required tools on the Ubuntu VM

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Update system
update_system() {
    log_step "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    log_info "System updated successfully!"
}

# Install Azure CLI
install_azure_cli() {
    log_step "Installing Azure CLI..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    log_info "Azure CLI installed successfully!"
}

# Install Docker
install_docker() {
    log_step "Installing Docker..."
    
    # Remove old versions
    sudo apt remove docker docker-engine docker.io containerd runc -y
    
    # Install prerequisites
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_info "Docker installed and started successfully!"
}

# Install kubectl
install_kubectl() {
    log_step "Installing kubectl..."
    
    # Download kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    # Make it executable
    chmod +x kubectl
    
    # Move to PATH
    sudo mv kubectl /usr/local/bin/
    
    log_info "kubectl installed successfully!"
}

# Install Node.js
install_nodejs() {
    log_step "Installing Node.js..."
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    
    log_info "Node.js installed successfully!"
}

# Install additional tools
install_additional_tools() {
    log_step "Installing additional tools..."
    
    # Install Git
    sudo apt install -y git
    
    # Install curl and wget
    sudo apt install -y curl wget
    
    # Install build essentials
    sudo apt install -y build-essential
    
    # Install jq for JSON processing
    sudo apt install -y jq
    
    log_info "Additional tools installed successfully!"
}

# Create project directory
create_project_directory() {
    log_step "Creating project directory..."
    
    mkdir -p ~/dynatrace-cicd-demo
    cd ~/dynatrace-cicd-demo
    
    log_info "Project directory created!"
}

# Install Helm (for Kubernetes package management)
install_helm() {
    log_step "Installing Helm..."
    
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
    sudo apt-get install apt-transport-https --yes
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
    sudo apt-get update
    sudo apt-get install helm
    
    log_info "Helm installed successfully!"
}

# Main installation function
main() {
    log_info "Starting Azure VM setup for Dynatrace CI/CD Demo..."
    
    update_system
    install_azure_cli
    install_docker
    install_kubectl
    install_nodejs
    install_additional_tools
    install_helm
    create_project_directory
    
    log_info "🎉 VM setup completed successfully!"
    log_info "All tools are now installed and ready for your Dynatrace CI/CD demo!"
    
    # Display installed versions
    echo ""
    log_info "Installed versions:"
    echo "Azure CLI: $(az --version --query '[0].\"azure-cli\"' -o tsv)"
    echo "Docker: $(docker --version)"
    echo "kubectl: $(kubectl version --client --output=yaml | grep gitVersion | cut -d'"' -f2)"
    echo "Node.js: $(node --version)"
    echo "npm: $(npm --version)"
    echo "Helm: $(helm version --short)"
    
    echo ""
    log_info "Next steps:"
    echo "1. Login to Azure: az login"
    echo "2. Upload your project code to ~/dynatrace-cicd-demo"
    echo "3. Deploy your application to Azure Kubernetes Service"
    echo "4. Configure Dynatrace monitoring"
}

# Run main function
main
