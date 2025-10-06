terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.113"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

locals {
  node_rg = azurerm_kubernetes_cluster.aks.node_resource_group
  kube_user  = try(azurerm_kubernetes_cluster.aks.kube_config[0], null)
  kube_admin = try(azurerm_kubernetes_cluster.aks.kube_admin_config[0], null)
  kube_used  = coalesce(local.kube_user, local.kube_admin)
}

provider "kubernetes" {
  host                   = try(local.kube_used.host, null)
  cluster_ca_certificate = try(base64decode(local.kube_used.cluster_ca_certificate), null)
  client_certificate     = try(base64decode(local.kube_used.client_certificate), null)
  client_key             = try(base64decode(local.kube_used.client_key), null)
}

provider "helm" {
  kubernetes {
    host                   = try(local.kube_used.host, null)
    cluster_ca_certificate = try(base64decode(local.kube_used.cluster_ca_certificate), null)
    client_certificate     = try(base64decode(local.kube_used.client_certificate), null)
    client_key             = try(base64decode(local.kube_used.client_key), null)
  }
}