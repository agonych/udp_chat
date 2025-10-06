# Define a namespace for Ingress-NGINX
resource "kubernetes_namespace" "ingress" {
  metadata { name = "ingress-nginx" }
  count = var.enable_k8s ? 1 : 0
}

# Create Ingress-NGINX in AKS using Helm
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.2"
  namespace  = kubernetes_namespace.ingress[0].metadata[0].name
  count      = var.enable_k8s ? 1 : 0

  # Link static IP to Ingress Controller
  set {
    name  = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.ingress.ip_address
  }

  # Ensure Azure LB forwards traffic correctly (uses node healthCheckNodePort)
  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  # Specify the node RG for the LB
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = azurerm_kubernetes_cluster.aks.node_resource_group
  }

  # Explicitly bind to the existing Public IP by name (recommended on AKS)
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-pip-name"
    value = azurerm_public_ip.ingress.name
  }

  # increase the nginx timeouts so nginx won't force close a websocket
  # connection
  # set { name = "controller.config.proxy-read-timeout"  value = "3600" }
  # set { name = "controller.config.proxy-send-timeout"  value = "3600" }

  depends_on = [
    kubernetes_namespace.ingress,
    azurerm_public_ip.ingress
  ]
}
