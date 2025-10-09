#!/usr/bin/env bash

# AKS Login Script
# Authenticate kubectl to AKS cluster using Terraform outputs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Show help
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Authenticate kubectl to AKS cluster"
    echo ""
    echo "Usage:"
    echo "  ./deploy/scripts/aks-login.sh"
    echo ""
    echo "This script reads AKS cluster info from Terraform outputs and configures kubectl."
    echo "Prerequisites:"
    echo "  - Run 'az login' first"
    echo "  - Run './deploy/scripts/infra-up.sh' to create the cluster"
    exit 0
fi

echo -e "${CYAN}AKS Login Script${NC}"

# Get script directory and resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="$REPO_ROOT/deploy/terraform"

# Read Terraform outputs for AKS
if [[ ! -d "$TF_DIR" ]]; then
    echo -e "${RED}Error: Terraform directory not found${NC}"
    echo -e "${YELLOW}Make sure you're in the correct project directory${NC}"
    exit 1
fi

pushd "$TF_DIR" >/dev/null

AKS_CLUSTER_NAME=$(terraform output -raw aks_name 2>/dev/null || true)
AKS_RESOURCE_GROUP=$(terraform output -raw resource_group 2>/dev/null || true)

popd >/dev/null

if [[ -z "$AKS_CLUSTER_NAME" ]] || [[ -z "$AKS_RESOURCE_GROUP" ]]; then
    echo -e "${RED}Error: Could not get AKS cluster information from Terraform${NC}"
    echo -e "${YELLOW}Make sure infrastructure is deployed: ./deploy/scripts/infra-up.sh${NC}"
    exit 1
fi

echo -e "Cluster: ${CYAN}$AKS_CLUSTER_NAME${NC}"
echo -e "Resource Group: ${CYAN}$AKS_RESOURCE_GROUP${NC}"
echo ""

# Get credentials
echo -e "${YELLOW}Getting AKS credentials from Azure...${NC}"
if az aks get-credentials --resource-group "$AKS_RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --overwrite-existing 2>&1 | grep -v "WARNING"; then
    echo -e "${GREEN}[OK] Credentials configured successfully${NC}"
else
    echo -e "${RED}Error: Failed to get AKS credentials${NC}"
    echo -e "${YELLOW}Make sure you're logged in: az login${NC}"
    exit 1
fi

# Test connection
echo ""
echo -e "${YELLOW}Testing connection to cluster...${NC}"
if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Successfully connected to AKS cluster!${NC}"
    echo ""
    echo -e "${CYAN}Cluster nodes:${NC}"
    kubectl get nodes
    echo ""
    echo -e "${CYAN}Current context:${NC}"
    kubectl config current-context
else
    echo -e "${YELLOW}Warning: Credentials configured but cannot connect to cluster${NC}"
    echo -e "${YELLOW}Check your network connection or VPN settings${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}[OK] You are now authenticated to AKS. You can run deployment scripts.${NC}"

