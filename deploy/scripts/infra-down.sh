#!/usr/bin/env bash
set -e

# Navigate to the terraform directory
cd "$(dirname "$0")/../terraform"

# Destroy the Terraform-managed infrastructure
# Two-phase destroy: first k8s/helm/dns, then base Azure infra

# Phase 1: destroy k8s/helm/dns (including ClusterIssuer)
terraform destroy -auto-approve -input=false -var enable_k8s=true -var enable_clusterissuer=true

# Phase 2: destroy base Azure infra
terraform destroy -auto-approve -input=false -var enable_k8s=false
