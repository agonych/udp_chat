variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = ""
}
variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  default     = ""
}
variable "client_id" {
  description = "Azure Client ID"
  type        = string
  default     = ""
}
variable "client_secret" {
  description = "Azure Client Secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "prefix" {
  description = "Deployment refix for all resources"
  type        = string
  default     = "udpchatnew"
}

variable "aks_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.31.7"
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS cluster"
  type        = number
  default     = 1
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "pg_admin_user" {
  description = "Postgres admin username (no @)"
  type        = string
  default     = "pgadmin"
}

variable "pg_admin_password" {
  description = "Postgres admin password"
  type        = string
  sensitive   = true
}

variable "pg_database_name" {
  description = "Initial application database name"
  type        = string
  default     = "udpchat"
}

variable "project_dns_zone" {
  description = "DNS zone for the project (e.g. example.com)"
  type        = string
  default     = "example.com"
}

variable "acme_email" {
  description = "Email address for ACME (Let's Encrypt) registration"
  type        = string
  default     = ""
}

variable "active_colour" {
  description = "Active colour for blue-green deployment"
  type        = string
  default     = "blue" # blue or green
}

variable "enable_k8s" {
  description = "Whether to create Kubernetes/Helm resources (run second apply when true)"
  type        = bool
  default     = false
}

variable "enable_clusterissuer" {
  description = "Whether to create the cert-manager ClusterIssuer (requires CRDs to already exist)"
  type        = bool
  default     = false
}
