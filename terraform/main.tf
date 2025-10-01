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

# PostgreSQL Server
resource "azurerm_postgresql_server" "postgres" {
  name                = var.postgres_server_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  
  sku_name = var.postgres_sku
  version  = var.postgres_version
  
  storage_mb                   = var.postgres_storage_mb
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true
  
  administrator_login          = var.postgres_admin_username
  administrator_login_password = var.postgres_admin_password
  
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
  
  tags = var.tags
}

# PostgreSQL Database
resource "azurerm_postgresql_database" "db" {
  name                = var.postgres_database_name
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_postgresql_server.postgres.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# PostgreSQL Firewall Rule - Allow Azure Services
resource "azurerm_postgresql_firewall_rule" "azure_services" {
  name                = "AllowAzureServices"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_postgresql_server.postgres.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# PostgreSQL Firewall Rule - Allow All (for testing only)
# IMPORTANT: Remove this in production!
resource "azurerm_postgresql_firewall_rule" "allow_all" {
  name                = "AllowAll"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_postgresql_server.postgres.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}


