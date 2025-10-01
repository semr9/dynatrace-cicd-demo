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

# Automated Database Initialization
resource "null_resource" "init_database" {
  # Re-run if database changes or SQL script changes
  triggers = {
    database_id = azurerm_postgresql_database.db.id
    script_hash = filemd5("${path.module}/../database/init.sql")
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      Write-Host "========================================" -ForegroundColor Cyan
      Write-Host "  Database Initialization" -ForegroundColor Cyan
      Write-Host "========================================" -ForegroundColor Cyan
      Write-Host ""
      Write-Host "Waiting for PostgreSQL to be fully ready..." -ForegroundColor Yellow
      Start-Sleep -Seconds 45
      
      Write-Host "Reading SQL initialization script..." -ForegroundColor Cyan
      
      # Read and clean SQL file (remove \c command for Azure)
      $sql = Get-Content "${path.module}/../database/init.sql" -Raw
      $sql = $sql -replace '-- Connect to ecommerce database.*\r?\n\\c ecommerce;\r?\n', ''
      $sql = $sql -replace '\\c ecommerce;', ''
      
      # Save to temporary file
      $tempFile = New-TemporaryFile
      $newTempFile = "$tempFile.sql"
      Move-Item $tempFile $newTempFile -Force
      $sql | Out-File -FilePath $newTempFile -Encoding UTF8 -NoNewline
      
      Write-Host "Executing SQL script on Azure PostgreSQL..." -ForegroundColor Cyan
      Write-Host "Server: ${azurerm_postgresql_server.postgres.fqdn}" -ForegroundColor Gray
      Write-Host "Database: ${var.postgres_database_name}" -ForegroundColor Gray
      Write-Host ""
      
      # Set password environment variable
      $env:PGPASSWORD = "${var.postgres_admin_password}"
      
      # Execute SQL using psql
      # Azure PostgreSQL format: username@servername
      psql -h ${azurerm_postgresql_server.postgres.fqdn} `
           -U ${var.postgres_admin_username}@${azurerm_postgresql_server.postgres.name} `
           -d ${var.postgres_database_name} `
           -f $newTempFile `
           --set=sslmode=require `
           -v ON_ERROR_STOP=1
      
      if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Database Initialized Successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Tables created:" -ForegroundColor Cyan
        Write-Host "  - users" -ForegroundColor White
        Write-Host "  - products" -ForegroundColor White
        Write-Host "  - orders" -ForegroundColor White
        Write-Host "  - order_items" -ForegroundColor White
        Write-Host "  - cart" -ForegroundColor White
        Write-Host "  - payments" -ForegroundColor White
        Write-Host ""
        Write-Host "Sample data inserted!" -ForegroundColor Green
      } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  Database Initialization Failed!" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please check the error above." -ForegroundColor Yellow
        Write-Host "You may need to run the SQL manually:" -ForegroundColor Yellow
        Write-Host 'psql "postgresql://${var.postgres_admin_username}@${azurerm_postgresql_server.postgres.name}:${var.postgres_admin_password}@${azurerm_postgresql_server.postgres.fqdn}:5432/${var.postgres_database_name}?sslmode=require" -f database/init.sql' -ForegroundColor Gray
        exit 1
      }
      
      # Cleanup
      Remove-Item $newTempFile -ErrorAction SilentlyContinue
    EOT
    
    interpreter = ["PowerShell", "-Command"]
  }
  
  depends_on = [
    azurerm_postgresql_server.postgres,
    azurerm_postgresql_database.db,
    azurerm_postgresql_firewall_rule.allow_all
  ]
}

