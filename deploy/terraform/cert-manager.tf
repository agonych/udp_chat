# Create a namespace for cert-manager
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
  count = var.enable_k8s ? 1 : 0
}

# Create a cert-manager in AKS using Helm
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.15.3"
  namespace  = kubernetes_namespace.cert_manager[0].metadata[0].name
  count      = var.enable_k8s ? 1 : 0

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.cert_manager,
    helm_release.ingress_nginx
  ]
}

# Create a ClusterIssuer for Let's Encrypt using HTTP-01 challenge
resource "kubernetes_manifest" "le_clusterissuer" {
  count = var.enable_k8s && var.enable_clusterissuer ? 1 : 0
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata   = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email               = var.acme_email
        server              = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = { name = "le-prod-key" }
        solvers = [
          # Use Azure DNS for wildcard certificates in prod
          {
            dns01 = {
              azureDNS = {
                clientID                = var.client_id
                clientSecretSecretRef   = { name = "azuredns-config", key = "client-secret" }
                subscriptionID          = var.subscription_id
                tenantID                = var.tenant_id
                resourceGroupName       = data.azurerm_resource_group.rg.name
                hostedZoneName          = var.project_dns_zone
                environment             = "AzurePublicCloud"
              }
            }
          },
          # Fallback to HTTP-01 via nginx for non-wildcard (e.g., testing)
          {
            http01 = {
              ingress = { class = "nginx" }
            }
          }
        ]
      }
    }
  }
  depends_on = [
    helm_release.cert_manager,
    helm_release.ingress_nginx
  ]
}

# Secret for Azure DNS solver (use native Secret to avoid stringData drift)
resource "kubernetes_secret" "azuredns_config" {
  count = var.enable_k8s && var.enable_clusterissuer ? 1 : 0
  metadata {
    name      = "azuredns-config"
    namespace = kubernetes_namespace.cert_manager[0].metadata[0].name
  }
  type = "Opaque"
  data = {
    "client-secret" = var.client_secret
  }
  depends_on = [
    helm_release.cert_manager
  ]
}
