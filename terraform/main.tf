# Main Azure Infrastructure Configuration

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.acr_sku
  admin_enabled       = true
  tags                = var.tags
}

# PostgreSQL removed - using in-cluster pod instead
# See k8s-manifests/applications/postgres/

# PostgreSQL removed - using in-cluster pod instead
# See k8s-manifests/applications/postgres/

# PostgreSQL removed - using in-cluster pod instead
# See k8s-manifests/applications/postgres/

# PostgreSQL removed - using in-cluster pod instead
# See k8s-manifests/applications/postgres/

