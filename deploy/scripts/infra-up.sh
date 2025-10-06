#!/usr/bin/env bash
set -e

# Navigate to the terraform directory
cd "$(dirname "$0")/../terraform"

# Initialize and apply the Terraform configuration
terraform init -upgrade

# Phase 1: base Azure infra (AKS/ACR/PG/IP), skip Kubernetes/Helm
terraform apply -auto-approve -input=false -var enable_k8s=false

# Phase 2: Kubernetes/Helm/DNS now that AKS API is ready
terraform apply -auto-approve -input=false -var enable_k8s=true

# Phase 3: create ClusterIssuer after CRDs are present
terraform apply -auto-approve -input=false -var enable_k8s=true -var enable_clusterissuer=true
