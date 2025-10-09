# Get the DNS zone (must exist in Azure DNS of the account)
data "azurerm_dns_zone" "chat" {
  name                = var.project_dns_zone
  resource_group_name = data.azurerm_resource_group.rg.name
}

# A record for test environment
resource "azurerm_dns_a_record" "testing" {
  count               = var.enable_k8s ? 1 : 0
  name                = "testing"
  zone_name           = data.azurerm_dns_zone.chat.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records             = [azurerm_public_ip.ingress.ip_address]
}

# A records for blue production environment
resource "azurerm_dns_a_record" "blue" {
  count               = var.enable_k8s ? 1 : 0
  name                = "blue"
  zone_name           = data.azurerm_dns_zone.chat.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records             = [azurerm_public_ip.ingress.ip_address]
}

# A records for green production environment
resource "azurerm_dns_a_record" "green" {
  count               = var.enable_k8s ? 1 : 0
  name                = "green"
  zone_name           = data.azurerm_dns_zone.chat.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records             = [azurerm_public_ip.ingress.ip_address]
}

# A record for www - points directly to ingress IP
# Ingress controller routes to active color based on Kubernetes ingress rules
resource "azurerm_dns_a_record" "www" {
  count               = var.enable_k8s ? 1 : 0
  name                = "www"
  zone_name           = data.azurerm_dns_zone.chat.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records             = [azurerm_public_ip.ingress.ip_address]
}

# A record for Grafana monitoring
resource "azurerm_dns_a_record" "grafana" {
  count               = var.enable_k8s ? 1 : 0
  name                = "grafana"
  zone_name           = data.azurerm_dns_zone.chat.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records             = [azurerm_public_ip.ingress.ip_address]
}

# A record for Prometheus monitoring
resource "azurerm_dns_a_record" "prometheus" {
  count               = var.enable_k8s ? 1 : 0
  name                = "prometheus"
  zone_name           = data.azurerm_dns_zone.chat.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records             = [azurerm_public_ip.ingress.ip_address]
}
