# Terraform Variables for Azure AKS Deployment

# General Configuration
variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "dynatrace-cicd"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "demo"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

# Resource Group
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "dynatrace-cicd-rg"
}

# Azure Container Registry
variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
  default     = "dynatracecicdacr"
}

variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

# PostgreSQL Configuration
variable "postgres_server_name" {
  description = "Name of the PostgreSQL server"
  type        = string
  default     = "dynatrace-cicd-postgres"
}

variable "postgres_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "dynatraceadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  default     = "Dynatrace2025!"
  sensitive   = true
}

variable "postgres_database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "ecommerce"
}

variable "postgres_sku" {
  description = "PostgreSQL SKU name"
  type        = string
  default     = "B_Gen5_1"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 5120
}

variable "postgres_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "11"
}

# AKS Configuration
variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "dynatrace-cicd-aks"
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS cluster"
  type        = number
  default     = 1
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2s"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28"
}

# Kubernetes Configuration
variable "kubernetes_namespace" {
  description = "Kubernetes namespace for application"
  type        = string
  default     = "dynatrace-cicd"
}

variable "jwt_secret" {
  description = "JWT secret for authentication"
  type        = string
  default     = "dynatrace-cicd-jwt-secret-2025"
  sensitive   = true
}

# Application Configuration
variable "frontend_replicas" {
  description = "Number of frontend replicas"
  type        = number
  default     = 1
}

variable "backend_replicas" {
  description = "Number of backend service replicas"
  type        = number
  default     = 1
}

# Dynatrace Configuration (optional)
variable "dynatrace_environment_id" {
  description = "Dynatrace environment ID"
  type        = string
  default     = ""
}

variable "dynatrace_api_token" {
  description = "Dynatrace API token"
  type        = string
  default     = ""
  sensitive   = true
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Dynatrace CI/CD Demo"
    Environment = "Demo"
    ManagedBy   = "Terraform"
  }
}


