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

# Two-phase destroy: first remove Kubernetes/Helm/DNS, then base Azure infra
# Phase 1: destroy k8s/helm/dns (including ClusterIssuer) by applying with enable_k8s=false
terraform apply -auto-approve -input=false
# Phase 2: destroy the rest of the infra
terraform destroy -auto-approve -input=false

echo -e "\n${GREEN}Infrastructure teardown complete${NC}"