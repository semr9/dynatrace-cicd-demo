# Terraform Variables Configuration
# Customize these values for your deployment

# General Configuration
project_name = "dynatrace-cicd"
environment  = "demo"
location     = "East US"

# Resource Group
resource_group_name = "dynatrace-cicd-rg"

# Azure Container Registry
acr_name = "dynatracecicdacr"
acr_sku  = "Basic"

# PostgreSQL Configuration
postgres_server_name    = "dynatrace-cicd-postgres"
postgres_admin_username = "dynatraceadmin"
postgres_admin_password = "Dynatrace2025!"
postgres_database_name  = "ecommerce"
postgres_sku            = "B_Gen5_1" # Basic tier: 1 vCore, 2GB RAM
postgres_storage_mb     = 32768      # 5GB
postgres_version        = "11"

# AKS Configuration
aks_cluster_name       = "dynatrace-cicd-aks"
aks_node_count         = 2
aks_vm_size            = "Standard_B2s" # 2 vCPU, 4GB RAM
aks_kubernetes_version = "1.31"

# Kubernetes Configuration
kubernetes_namespace = "dynatrace-cicd"
jwt_secret           = "dynatrace-cicd-jwt-secret-2025"

# Application Configuration
frontend_replicas = 1
backend_replicas  = 1

# Dynatrace Configuration (optional)
# Uncomment and fill in your Dynatrace details
# dynatrace_environment_id = "abc12345"
# dynatrace_api_token      = "dt0c01.ABC123..."

# Tags
tags = {
  Project     = "Dynatrace CI/CD Demo"
  Environment = "Demo"
  ManagedBy   = "Terraform"
  Owner       = "sebastian.moscoso@dynatrace.com"
}


