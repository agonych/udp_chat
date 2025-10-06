# Use this existing resource group
data "azurerm_resource_group" "rg" {
  name = var.prefix
}

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
  name                              = "${var.prefix}aks"
  location                          = data.azurerm_resource_group.rg.location
  resource_group_name               = data.azurerm_resource_group.rg.name
  dns_prefix                        = var.prefix
  kubernetes_version                = var.aks_version
  local_account_disabled            = false
  role_based_access_control_enabled = true

  default_node_pool {
    name       = "default"
    node_count = var.aks_node_count
    vm_size    = var.aks_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      # Avoid terraform upgrade_settings churn
      default_node_pool[0].upgrade_settings
    ]
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

# Reserve static public IP for wildcard ingress controller
resource "azurerm_public_ip" "ingress" {
  name                = "${var.prefix}-ingress-ip"
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = {
    service = "wildcard-ingress"
  }
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

  lifecycle {
    ignore_changes = [
      zone
    ]
  }
}

# Application database
resource "azurerm_postgresql_flexible_server_database" "appdb" {
  name      = var.pg_database_name
  server_id = azurerm_postgresql_flexible_server.pg.id
  collation = "en_US.utf8"
  charset   = "UTF8"
}

# Simple, permissive firewall for initial connectivity to Postgres
# WARNING: This is wide-open. Must be locked down before production use.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name      = "allow-all-for-initial-setup"
  server_id = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}
