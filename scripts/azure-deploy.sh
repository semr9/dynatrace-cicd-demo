#!/bin/bash

# Azure Deployment Script for Dynatrace CI/CD Demo
# This script creates all necessary Azure resources and deploys the application

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

# Check if Azure CLI is installed
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    print_success "Azure CLI is installed"
}

# Check if user is logged in
check_azure_login() {
    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    print_success "Logged in to Azure"
}

# Load configuration
load_config() {
    if [ ! -f "azure/config.yaml" ]; then
        print_error "Configuration file azure/config.yaml not found"
        exit 1
    fi
    
    # Source the config (simple YAML parsing)
    source <(grep -v '^#' azure/config.yaml | grep -v '^$' | sed 's/:/=/' | sed 's/^[[:space:]]*//')
    print_success "Configuration loaded"
}

# Create resource group
create_resource_group() {
    print_status "Creating resource group: $resourceGroup"
    
    if az group show --name "$resourceGroup" &> /dev/null; then
        print_warning "Resource group $resourceGroup already exists"
    else
        az group create \
            --name "$resourceGroup" \
            --location "$location" \
            --output table
        print_success "Resource group created"
    fi
}

# Create Azure Container Registry
create_acr() {
    print_status "Creating Azure Container Registry: $acrName"
    
    if az acr show --name "$acrName" --resource-group "$resourceGroup" &> /dev/null; then
        print_warning "ACR $acrName already exists"
    else
        az acr create \
            --resource-group "$resourceGroup" \
            --name "$acrName" \
            --sku "$acrSku" \
            --admin-enabled true \
            --output table
        print_success "ACR created"
    fi
}

# Create Azure Database for PostgreSQL
create_postgres() {
    print_status "Creating Azure Database for PostgreSQL: $postgresServerName"
    
    if az postgres server show --name "$postgresServerName" --resource-group "$resourceGroup" &> /dev/null; then
        print_warning "PostgreSQL server $postgresServerName already exists"
    else
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
        
        # Configure firewall to allow Azure services
        az postgres server firewall-rule create \
            --resource-group "$resourceGroup" \
            --server "$postgresServerName" \
            --name "AllowAzureServices" \
            --start-ip-address 0.0.0.0 \
            --end-ip-address 0.0.0.0 \
            --output table
        
        print_success "PostgreSQL server and database created"
    fi
}

# Create Azure Kubernetes Service
create_aks() {
    print_status "Creating AKS cluster: $aksClusterName"
    
    if az aks show --name "$aksClusterName" --resource-group "$resourceGroup" &> /dev/null; then
        print_warning "AKS cluster $aksClusterName already exists"
    else
        # Get ACR login server
        ACR_LOGIN_SERVER=$(az acr show --name "$acrName" --resource-group "$resourceGroup" --query loginServer --output tsv)
        
    # Create AKS cluster (cost-optimized for testing)
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
        
        print_success "AKS cluster created"
    fi
}

# Get AKS credentials
get_aks_credentials() {
    print_status "Getting AKS credentials"
    
    az aks get-credentials \
        --resource-group "$resourceGroup" \
        --name "$aksClusterName" \
        --overwrite-existing
    
    print_success "AKS credentials configured"
}

# Build and push Docker images
build_and_push_images() {
    print_status "Building and pushing Docker images to ACR"
    
    # Get ACR login server
    ACR_LOGIN_SERVER=$(az acr show --name "$acrName" --resource-group "$resourceGroup" --query loginServer --output tsv)
    
    # Login to ACR
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
}

# Deploy to Kubernetes
deploy_to_k8s() {
    print_status "Deploying application to Kubernetes"
    
    # Get ACR login server
    ACR_LOGIN_SERVER=$(az acr show --name "$acrName" --resource-group "$resourceGroup" --query loginServer --output tsv)
    
    # Get PostgreSQL connection string
    POSTGRES_CONNECTION_STRING="postgresql://$postgresAdminLogin:$postgresAdminPassword@$postgresServerName.postgres.database.azure.com:5432/$postgresDatabaseName?sslmode=require"
    
    # Create namespace
    kubectl create namespace "$appNamespace" --dry-run=client -o yaml | kubectl apply -f -
    
    # Update ConfigMap with Azure-specific values
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
    
    # Update deployments with ACR images
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
    kubectl apply -f azure/k8s-configmap.yaml
    kubectl apply -f azure/k8s-deployments.yaml
    kubectl apply -f k8s/services.yaml
    kubectl apply -f k8s/ingress.yaml
    
    print_success "Application deployed to Kubernetes"
}

# Wait for deployment
wait_for_deployment() {
    print_status "Waiting for deployment to be ready"
    
    kubectl wait --for=condition=available --timeout=300s deployment/frontend -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/api-gateway -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/user-service -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/product-service -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/order-service -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/payment-service -n "$appNamespace"
    kubectl wait --for=condition=available --timeout=300s deployment/redis -n "$appNamespace"
    
    print_success "All deployments are ready"
}

# Get application URL
get_application_url() {
    print_status "Getting application URL"
    
    # Get external IP
    EXTERNAL_IP=$(kubectl get service frontend-service -n "$appNamespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    
    if [ -z "$EXTERNAL_IP" ]; then
        print_warning "External IP not yet assigned. You can check with: kubectl get services -n $appNamespace"
    else
        print_success "Application is available at: http://$EXTERNAL_IP"
    fi
}

# Main deployment function
main() {
    print_status "Starting Azure deployment for Dynatrace CI/CD Demo"
    
    check_azure_cli
    check_azure_login
    load_config
    
    create_resource_group
    create_acr
    create_postgres
    create_aks
    get_aks_credentials
    build_and_push_images
    deploy_to_k8s
    wait_for_deployment
    get_application_url
    
    print_success "Azure deployment completed successfully!"
    print_status "You can now access your application and configure Dynatrace monitoring"
}

# Run main function
main "$@"
