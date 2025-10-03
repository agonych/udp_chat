output "resource_group" {
  description = "Resource Group name"
  value       = data.azurerm_resource_group.rg.name
}

output "aks_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity"
  value       = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "acr_login_server" {
  description = "ACR login server (use for docker login/push)"
  value       = azurerm_container_registry.acr.login_server
}

output "postgres_fqdn" {
  description = "PostgreSQL Flexible Server FQDN"
  value       = azurerm_postgresql_flexible_server.pg.fqdn
}

output "ingress_ip" {
  description = "Static IP address for wildcard ingress controller"
  value       = azurerm_public_ip.ingress.ip_address
}

output "ingress_ip_name" {
  description = "Static IP resource name"
  value       = azurerm_public_ip.ingress.name
}

output "aks_node_resource_group" {
  description = "AKS node resource group (where LB resources are created)"
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "dns_zone_name" {
  description = "DNS zone name for external-dns"
  value       = data.azurerm_dns_zone.chat.name
}
