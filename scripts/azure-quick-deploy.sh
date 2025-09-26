#!/bin/bash

# Quick Azure Deployment Script for Dynatrace CI/CD Demo
# This script provides step-by-step deployment with user interaction

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

# Function to prompt user
prompt_user() {
    echo -e "${YELLOW}$1${NC}"
    read -p "Press Enter to continue or Ctrl+C to exit..."
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in
    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    print_success "All prerequisites are met"
}

# Load and display configuration
load_config() {
    if [ ! -f "azure/config.yaml" ]; then
        print_error "Configuration file azure/config.yaml not found"
        exit 1
    fi
    
    print_status "Current configuration:"
    echo "----------------------------------------"
    cat azure/config.yaml
    echo "----------------------------------------"
    
    prompt_user "Please review the configuration above. Make sure to update the Dynatrace values in azure/config.yaml before proceeding."
}

# Step 1: Create Azure Resources
step1_create_resources() {
    print_status "Step 1: Creating Azure Resources"
    prompt_user "This will create: Resource Group, ACR, PostgreSQL, and AKS cluster"
    
    # Source the config
    source <(grep -v '^#' azure/config.yaml | grep -v '^$' | sed 's/:/=/' | sed 's/^[[:space:]]*//')
    
    # Create resource group
    print_status "Creating resource group: $resourceGroup"
    az group create --name "$resourceGroup" --location "$location" --output table
    
    # Create ACR
    print_status "Creating Azure Container Registry: $acrName"
    az acr create --resource-group "$resourceGroup" --name "$acrName" --sku "$acrSku" --admin-enabled true --output table
    
    # Create PostgreSQL
    print_status "Creating Azure Database for PostgreSQL: $postgresServerName"
    az postgres server create \
        --resource-group "$resourceGroup" \
        --name "$postgresServerName" \
        --location "$location" \
        --admin-user "$postgresAdminLogin" \
        --admin-password "$postgresAdminPassword" \
        --sku-name "$postgresSku" \
        --output table
    
    # Create database
    az postgres db create \
        --resource-group "$resourceGroup" \
        --server-name "$postgresServerName" \
        --name "$postgresDatabaseName" \
        --output table
    
    # Configure firewall
    az postgres server firewall-rule create \
        --resource-group "$resourceGroup" \
        --server "$postgresServerName" \
        --name "AllowAzureServices" \
        --start-ip-address 0.0.0.0 \
        --end-ip-address 0.0.0.0 \
        --output table
    
    # Create AKS
    print_status "Creating AKS cluster: $aksClusterName"
    az aks create \
        --resource-group "$resourceGroup" \
        --name "$aksClusterName" \
        --node-count "$aksNodeCount" \
        --node-vm-size "$aksVmSize" \
        --kubernetes-version "$aksVersion" \
        --attach-acr "$acrName" \
        --enable-managed-identity \
        --enable-addons monitoring \
        --generate-ssh-keys \
        --output table
    
    print_success "Step 1 completed: Azure resources created"
}

# Step 2: Configure Kubernetes
step2_configure_k8s() {
    print_status "Step 2: Configuring Kubernetes"
    prompt_user "This will get AKS credentials and configure kubectl"
    
    # Source the config
    source <(grep -v '^#' azure/config.yaml | grep -v '^$' | sed 's/:/=/' | sed 's/^[[:space:]]*//')
    
    # Get AKS credentials
    print_status "Getting AKS credentials"
    az aks get-credentials --resource-group "$resourceGroup" --name "$aksClusterName" --overwrite-existing
    
    # Verify connection
    print_status "Verifying Kubernetes connection"
    kubectl get nodes
    
    print_success "Step 2 completed: Kubernetes configured"
}

# Step 3: Build and Push Images
step3_build_images() {
    print_status "Step 3: Building and Pushing Docker Images"
    prompt_user "This will build all Docker images and push them to ACR"
    
    # Source the config
    source <(grep -v '^#' azure/config.yaml | grep -v '^$' | sed 's/:/=/' | sed 's/^[[:space:]]*//')
    
    # Get ACR login server
    ACR_LOGIN_SERVER=$(az acr show --name "$acrName" --resource-group "$resourceGroup" --query loginServer --output tsv)
    
    # Login to ACR
    print_status "Logging in to ACR"
    az acr login --name "$acrName"
    
    # Build and push images
    services=("frontend" "api-gateway" "user-service" "product-service" "order-service" "payment-service")
    
    for service in "${services[@]}"; do
        print_status "Building and pushing $service image"
        
        if [ "$service" = "frontend" ]; then
            docker build -t "$ACR_LOGIN_SERVER/$service:latest" ./frontend/
        else
            docker build -t "$ACR_LOGIN_SERVER/$service:latest" ./backend/$service/
        fi
        
        docker push "$ACR_LOGIN_SERVER/$service:latest"
        print_success "$service image pushed"
    done
    
    print_success "Step 3 completed: Docker images built and pushed"
}

# Step 4: Deploy Application
step4_deploy_app() {
    print_status "Step 4: Deploying Application to Kubernetes"
    prompt_user "This will deploy the application to AKS"
    
    # Source the config
    source <(grep -v '^#' azure/config.yaml | grep -v '^$' | sed 's/:/=/' | sed 's/^[[:space:]]*//')
    
    # Get ACR login server
    ACR_LOGIN_SERVER=$(az acr show --name "$acrName" --resource-group "$resourceGroup" --query loginServer --output tsv)
    
    # Get PostgreSQL connection string
    POSTGRES_CONNECTION_STRING="postgresql://$postgresAdminLogin:$postgresAdminPassword@$postgresServerName.postgres.database.azure.com:5432/$postgresDatabaseName?sslmode=require"
    
    # Create namespace
    print_status "Creating namespace: $appNamespace"
    kubectl create namespace "$appNamespace" --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ConfigMap
    print_status "Creating ConfigMap"
    cat > azure/k8s-configmap.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: $appNamespace
data:
  DATABASE_URL: "$POSTGRES_CONNECTION_STRING"
  REDIS_URL: "redis://redis-service:6379"
  JWT_SECRET: "dynatrace-cicd-jwt-secret-2025"
  NODE_ENV: "production"
EOF
    
    # Create deployments
    print_status "Creating deployments"
    cat > azure/k8s-deployments.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: $appNamespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: $ACR_LOGIN_SERVER/frontend:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: $appNamespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: $ACR_LOGIN_SERVER/api-gateway:latest
        ports:
        - containerPort: 3000
        env:
        - name: USER_SERVICE_URL
          value: "http://user-service:3001"
        - name: PRODUCT_SERVICE_URL
          value: "http://product-service:3002"
        - name: ORDER_SERVICE_URL
          value: "http://order-service:3003"
        - name: PAYMENT_SERVICE_URL
          value: "http://payment-service:3004"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: $appNamespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: $ACR_LOGIN_SERVER/user-service:latest
        ports:
        - containerPort: 3001
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DATABASE_URL
        - name: JWT_SECRET
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: JWT_SECRET
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: $appNamespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      containers:
      - name: product-service
        image: $ACR_LOGIN_SERVER/product-service:latest
        ports:
        - containerPort: 3002
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DATABASE_URL
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: $appNamespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
    spec:
      containers:
      - name: order-service
        image: $ACR_LOGIN_SERVER/order-service:latest
        ports:
        - containerPort: 3003
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DATABASE_URL
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: REDIS_URL
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: $appNamespace
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
    spec:
      containers:
      - name: payment-service
        image: $ACR_LOGIN_SERVER/payment-service:latest
        ports:
        - containerPort: 3004
        env:
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DATABASE_URL
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: $appNamespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF
    
    # Apply Kubernetes manifests
    print_status "Applying Kubernetes manifests"
    kubectl apply -f azure/k8s-configmap.yaml
    kubectl apply -f azure/k8s-deployments.yaml
    kubectl apply -f k8s/services.yaml
    kubectl apply -f k8s/ingress.yaml
    
    print_success "Step 4 completed: Application deployed"
}

# Step 5: Verify Deployment
step5_verify_deployment() {
    print_status "Step 5: Verifying Deployment"
    prompt_user "This will check the deployment status and get the application URL"
    
    # Source the config
    source <(grep -v '^#' azure/config.yaml | grep -v '^$' | sed 's/:/=/' | sed 's/^[[:space:]]*//')
    
    # Wait for deployments
    print_status "Waiting for deployments to be ready"
    kubectl wait --for=condition=available --timeout=300s deployment/frontend -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/api-gateway -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/user-service -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/product-service -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/order-service -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/payment-service -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/redis -n "$appNamespace"
    
    # Show deployment status
    print_status "Deployment status:"
    kubectl get deployments -n "$appNamespace"
    
    # Show services
    print_status "Services:"
    kubectl get services -n "$appNamespace"
    
    # Get external IP
    print_status "Getting application URL..."
    EXTERNAL_IP=$(kubectl get service frontend-service -n "$appNamespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$EXTERNAL_IP" ]; then
        print_warning "External IP not yet assigned. You can check with: kubectl get services -n $appNamespace"
    else
        print_success "Application is available at: http://$EXTERNAL_IP"
    fi
    
    print_success "Step 5 completed: Deployment verified"
}

# Main menu
main_menu() {
    while true; do
        echo ""
        echo "=========================================="
        echo "  Azure Deployment for Dynatrace CI/CD Demo"
        echo "=========================================="
        echo "1. Check Prerequisites"
        echo "2. Load Configuration"
        echo "3. Step 1: Create Azure Resources"
        echo "4. Step 2: Configure Kubernetes"
        echo "5. Step 3: Build and Push Images"
        echo "6. Step 4: Deploy Application"
        echo "7. Step 5: Verify Deployment"
        echo "8. Run All Steps"
        echo "9. Exit"
        echo "=========================================="
        read -p "Select an option (1-9): " choice
        
        case $choice in
            1) check_prerequisites ;;
            2) load_config ;;
            3) step1_create_resources ;;
            4) step2_configure_k8s ;;
            5) step3_build_images ;;
            6) step4_deploy_app ;;
            7) step5_verify_deployment ;;
            8) 
                check_prerequisites
                load_config
                step1_create_resources
                step2_configure_k8s
                step3_build_images
                step4_deploy_app
                step5_verify_deployment
                print_success "All steps completed successfully!"
                break
                ;;
            9) 
                print_status "Exiting..."
                exit 0
                ;;
            *) 
                print_error "Invalid option. Please select 1-9."
                ;;
        esac
    done
}

# Run main menu
main_menu
