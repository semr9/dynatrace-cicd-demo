# Base Kubernetes Configuration (Managed by Terraform)
# Application deployments are managed by ArgoCD in k8s-manifests/

# Create Namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.kubernetes_namespace
    labels = {
      name        = var.kubernetes_namespace
      environment = var.environment
    }
  }
  
  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Create ConfigMap with infrastructure connection details
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  
  data = {
    DATABASE_URL = "postgresql://${var.postgres_admin_username}:${var.postgres_admin_password}@${azurerm_postgresql_server.postgres.fqdn}:5432/${var.postgres_database_name}?sslmode=require"
    REDIS_URL    = "redis://redis-service:6379"
    JWT_SECRET   = var.jwt_secret
    NODE_ENV     = "production"
  }
  
  depends_on = [
    azurerm_postgresql_server.postgres,
    azurerm_postgresql_database.db
  ]
}

# Create ACR Secret for pulling images
resource "kubernetes_secret" "acr_secret" {
  metadata {
    name      = "acr-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }
  
  type = "kubernetes.io/dockerconfigjson"
  
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${azurerm_container_registry.acr.login_server}" = {
          username = azurerm_container_registry.acr.admin_username
          password = azurerm_container_registry.acr.admin_password
          auth     = base64encode("${azurerm_container_registry.acr.admin_username}:${azurerm_container_registry.acr.admin_password}")
        }
      }
    })
  }
  
  depends_on = [azurerm_container_registry.acr]
}


# Build and Push Docker Images to ACR
resource "null_resource" "build_and_push_images" {
  triggers = {
    acr_login_server = azurerm_container_registry.acr.login_server
    timestamp        = timestamp()
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      Write-Host "========================================" -ForegroundColor Cyan
      Write-Host "  Building and Pushing Docker Images" -ForegroundColor Cyan
      Write-Host "========================================" -ForegroundColor Cyan
      Write-Host ""
      
      `$acrServer = "${azurerm_container_registry.acr.login_server}"
      `$acrName = "${azurerm_container_registry.acr.name}"
      
      Write-Host "ACR Server: `$acrServer" -ForegroundColor Yellow
      Write-Host "Logging in to ACR..." -ForegroundColor Cyan
      
      az acr login --name `$acrName
      
      if (`$LASTEXITCODE -ne 0) {
        Write-Host "Failed to login to ACR" -ForegroundColor Red
        exit 1
      }
      
      Write-Host "Login successful!" -ForegroundColor Green
      Write-Host ""
      
      `$services = @(
        @{Name="frontend"; Path="../frontend"},
        @{Name="api-gateway"; Path="../backend/api-gateway"},
        @{Name="user-service"; Path="../backend/user-service"},
        @{Name="product-service"; Path="../backend/product-service"},
        @{Name="order-service"; Path="../backend/order-service"},
        @{Name="payment-service"; Path="../backend/payment-service"}
      )
      
      `$total = `$services.Count
      `$current = 0
      
      foreach (`$service in `$services) {
        `$current++
        Write-Host "[`$current/`$total] Building `$(`$service.Name)..." -ForegroundColor Cyan
        
        `$imageName = "`$acrServer/`$(`$service.Name):latest"
        
        docker build -t `$imageName `$service.Path
        
        if (`$LASTEXITCODE -ne 0) {
          Write-Host "Failed to build `$(`$service.Name)" -ForegroundColor Red
          exit 1
        }
        
        Write-Host "  Pushing to ACR..." -ForegroundColor Yellow
        docker push `$imageName
        
        if (`$LASTEXITCODE -ne 0) {
          Write-Host "Failed to push `$(`$service.Name)" -ForegroundColor Red
          exit 1
        }
        
        Write-Host "  `$(`$service.Name) complete!" -ForegroundColor Green
        Write-Host ""
      }
      
      Write-Host "========================================" -ForegroundColor Green
      Write-Host "  All Images Built and Pushed!" -ForegroundColor Green
      Write-Host "========================================" -ForegroundColor Green
    EOT
    
    interpreter = ["PowerShell", "-Command"]
  }
  
  depends_on = [
    azurerm_container_registry.acr,
    azurerm_role_assignment.aks_acr
  ]
}

# Note: All application deployments and services are managed by ArgoCD
# See k8s-manifests/applications/ for application definitions


