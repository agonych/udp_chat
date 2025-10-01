# Use this existing resource group
data "azurerm_resource_group" "rg" {
  name = var.prefix
}

# Who runs Terraform
data "azurerm_client_config" "current" {}

# Create new ACR
resource "azurerm_container_registry" "acr" {
  name                = "${var.prefix}acr"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

# Create new AKS cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}aks"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  dns_prefix          = var.prefix
  kubernetes_version  = var.aks_version

  default_node_pool {
    name       = "default"
    node_count = var.aks_node_count
    vm_size    = var.aks_vm_size
  }

  identity {
    type = "SystemAssigned"
  }
}

# Reserve static public IP for ingress controller
resource "azurerm_public_ip" "ingress" {
  name                = "${var.prefix}-ingress-ip"
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = {
    service = "ingress-nginx"
  }
}

# Allow AKS to pull images from ACR (AcrPull)
resource "azurerm_role_assignment" "acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true

  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
}

# Key Vault for secrets
resource "azurerm_key_vault" "kv" {
  name                       = "${var.prefix}kv"
  resource_group_name        = data.azurerm_resource_group.rg.name
  location                   = data.azurerm_resource_group.rg.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = true
}

# Allow the current principal to manage secrets in this vault
resource "azurerm_role_assignment" "kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Postgres server
resource "azurerm_postgresql_flexible_server" "pg" {
  name                = "${var.prefix}pg"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  administrator_login    = var.pg_admin_user
  administrator_password = var.pg_admin_password
  sku_name   = "B_Standard_B1ms"
  version    = "16"
  storage_mb = 32768
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  public_network_access_enabled = true

  authentication {
    password_auth_enabled = true
  }
  
  # No zone specified - let Azure choose available zone
}

# Application database
resource "azurerm_postgresql_flexible_server_database" "appdb" {
  name      = var.pg_database_name
  server_id = azurerm_postgresql_flexible_server.pg.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Simple, permissive firewall for initial connectivity.
# WARNING: This is wide-open. Must be locked down before production use.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name      = "allow-all-for-initial-setup"
  server_id = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Store the Postgres admin password in Key Vault
resource "azurerm_key_vault_secret" "pg_admin_password" {
  name         = "PG-ADMIN-PASSWORD"
  value        = var.pg_admin_password
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [ azurerm_role_assignment.kv_secrets_officer ]
}

# Azure OpenAI resource (models are deployed separately via Azure CLI in CI)
# Note: OpenAI not available in all regions - using Australia East instead
resource "azurerm_cognitive_account" "aoai" {
  name                = "${var.prefix}aoai"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = "australiaeast"  # OpenAI available in australiaeast, not australiasoutheast
  kind                = "OpenAI"
  sku_name            = "S0"
}

# Get the existing DNS zone (assumes chat.kudriavcev.info exists)
data "azurerm_dns_zone" "chat" {
  name                = "chat.kudriavcev.info"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Allow AKS managed identity to manage DNS records (for external-dns)
resource "azurerm_role_assignment" "aks_dns_contributor" {
  scope                = data.azurerm_dns_zone.chat.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  
  depends_on = [azurerm_kubernetes_cluster.aks]
}
