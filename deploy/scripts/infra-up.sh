#!/usr/bin/env bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Navigate to the terraform directory
cd "$(dirname "$0")/../terraform"

# Initialize and apply the Terraform configuration
terraform init -upgrade

# Three-phase apply to handle dependencies properly
# Phase 1: create base Azure infra
terraform apply -auto-approve -input=false
# Phase 2: create Kubernetes/Helm/DNS
terraform apply -auto-approve -input=false -var enable_k8s=true
# Phase 3: create ClusterIssuer
terraform apply -auto-approve -input=false -var enable_k8s=true -var enable_clusterissuer=true

echo -e "\n${GREEN}Infrastructure deployment complete${NC}"