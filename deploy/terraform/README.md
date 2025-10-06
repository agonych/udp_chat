# UDP Chat - Azure Infrastructure with Terraform

This directory contains Terraform configuration for deploying UDP Chat infrastructure to Microsoft Azure.

## Overview

This Terraform configuration creates a complete Azure infrastructure stack for the UDP Chat application, including:

- **Azure Kubernetes Service (AKS)** - Container orchestration
- **Azure Container Registry (ACR)** - Container image storage
- **Azure PostgreSQL Flexible Server** - Database backend
- **Azure DNS Zone** - Domain management
- **Static Public IP** - For ingress controller

## Prerequisites

### Azure Requirements
- Azure subscription with appropriate permissions
- Azure DNS zone already created (e.g., `chat.kudriavtsev.info`)
- Resource group already created

### Local Requirements
- [Terraform](https://www.terraform.io/downloads)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

### Authentication with Service Principal
Edit `terraform.tfvars` with your values:

```hcl
subscription_id   = "your-azure-subscription-id"
tenant_id         = "your-azure-tenant-id"
client_id         = "your-service-principal-client-id"
client_secret     = "your-service-principal-secret"
pg_admin_password = "your-secure-postgres-password"
project_dns_zone  = "your-domain.com"
```

### 2. Key Variables

| Variable            | Description                 | Default           |
|---------------------|-----------------------------|-------------------|
| `prefix`            | Resource name prefix        | `udpchat`         |
| `aks_version`       | Kubernetes version          | `1.31.7`          |
| `aks_node_count`    | Number of AKS nodes         | `1`               |
| `aks_vm_size`       | VM size for AKS nodes       | `Standard_D2s_v3` |
| `project_dns_zone`  | DNS zone name               | `example.com`     |
| `pg_admin_user`     | PostgreSQL admin user       | `pgadmin`         |
| `pg_database_name`  | Application database name   | `udpchat`         |
| `pg_admin_password` | PostgreSQL admin password   | (required)        |
| `subscription_id`   | Azure subscription ID       | (required)        |
| `tenant_id`         | Azure tenant ID             | (required)        |
| `client_id`         | Service principal client ID | (required)        |
| `client_secret`     | Service principal secret    | (required)        |


## Deployment

### 1. Initialize Terraform
```bash
cd deploy/terraform
terraform init
# or to update settings
terraform init -upgrade
```

### 2. Three-phase Plan/Apply
```bash
# Phase 1: Base Azure infra only (AKS/ACR/Postgres/IP)
terraform plan
terraform apply --auto-approve

# Phase 2: Kubernetes/Helm/DNS (requires AKS to exist)
terraform plan -var enable_k8s=true
terraform apply --auto-approve -var enable_k8s=true

# Phase 3: cert-manager ClusterIssuer (ACME)
terraform plan -var enable_k8s=true -var enable_clusterissuer=true
terraform apply --auto-approve -var enable_k8s=true -var enable_clusterissuer=true
```

### 3. Configure kubectl (optional)
```bash
# Get AKS credentials
az aks get-credentials --resource-group $(terraform output -raw resource_group) --name $(terraform output -raw aks_name)

# Verify connection
kubectl get nodes
```

## Infrastructure Components

### Azure Kubernetes Service (AKS)
- **Name**: `{prefix}aks`
- **Version**: Configurable via `aks_version`
- **Nodes**: Configurable count and VM size
- **Identity**: System-assigned managed identity

### Azure Container Registry (ACR)
- **Name**: `{prefix}acr`
- **SKU**: Basic
- **Access**: AKS has AcrPull permissions

### Azure PostgreSQL Flexible Server
- **Name**: `{prefix}pg`
- **Version**: PostgreSQL 16
- **SKU**: B_Standard_B1ms (1 vCore, 2GB RAM)
- **Storage**: 32GB
- **Backup**: 7 days retention
- **Firewall**: Open for initial setup (⚠️ **Production Warning**)


### DNS and Networking
- **Static IP**: Reserved for ingress controller
- **Wildcard DNS**: `*.{project_dns_zone}` → Static IP
- **DNS Permissions**: AKS can manage DNS records

## Important Outputs

After deployment, Terraform provides these outputs:

```bash
# Get all outputs
terraform output

# Get specific outputs
terraform output aks_name
terraform output acr_login_server
terraform output postgres_fqdn
terraform output ingress_ip
```

### Key Outputs for Application Deployment

| Output             | Description                  | Usage                             |
|--------------------|------------------------------|-----------------------------------|
| `acr_login_server` | ACR URL for pushing images   | `docker login {acr_login_server}` |
| `postgres_fqdn`    | PostgreSQL connection string | Database connection               |
| `ingress_ip`       | Static IP for ingress        | DNS configuration                 |
| `aks_name`         | AKS cluster name             | kubectl configuration             |

## Security Considerations

### ⚠️ Production Warnings

1. **PostgreSQL Firewall**: Currently open to all IPs (`0.0.0.0/0`)
   - **Action Required**: Restrict to specific IP ranges before production

2. **Secrets in tfvars**: Sensitive values in `terraform.tfvars`
   - **Action Required**: Use environment variables or secure secret management

3. **Basic ACR SKU**: Using Basic tier
   - **Consider**: Upgrade to Standard/Premium for production features

### Useful Commands

```bash
# Check Terraform state
terraform show
terraform state list

# Import existing resources
terraform import azurerm_resource_group.rg /subscriptions/{sub}/resourceGroups/{rg}

# Destroy infrastructure (⚠️ DANGER)
terraform destroy

# Validate configuration
terraform validate
terraform fmt -check
```

## Cleanup

To destroy all resources (two phases, ordered to avoid provider issues):

```bash
# Phase 1: remove Kubernetes/Helm/DNS and ClusterIssuer
terraform destroy --auto-approve -var enable_k8s=true -var enable_clusterissuer=true

# Phase 2: remove base Azure infra
terraform destroy --auto-approve -var enable_k8s=false
```
