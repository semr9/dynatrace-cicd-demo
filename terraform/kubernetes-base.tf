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

# Note: All application deployments and services are managed by ArgoCD
# See k8s-manifests/applications/ for application definitions

