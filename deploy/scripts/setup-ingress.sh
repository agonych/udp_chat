#!/bin/bash

# Setup Ingress Controller Script for Linux
# Usage: ./setup-ingress.sh [-n <namespace>] [-r <release>] [-d <terraform-dir>] [-g <node-rg>] [--dry-run]

set -e

# Default values
NAMESPACE="ingress-nginx"
RELEASE="ingress-nginx"
TERRAFORM_DIR=""
NODE_RESOURCE_GROUP=""
DRY_RUN=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to show help
show_help() {
    echo "Setup Ingress Controller Script"
    echo ""
    echo "Usage:"
    echo "  ./setup-ingress.sh [-n <namespace>] [-r <release>] [-d <terraform-dir>] [-g <node-rg>] [--dry-run]"
    echo ""
    echo "Options:"
    echo "  -n, --namespace       Kubernetes namespace (default: ingress-nginx)"
    echo "  -r, --release         Helm release name (default: ingress-nginx)"
    echo "  -d, --terraform-dir   Terraform directory path"
    echo "  -g, --node-rg         AKS node resource group"
    echo "  --dry-run            Show commands without executing"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "This script sets up the ingress-nginx controller with static IP binding."
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE="$2"
            shift 2
            ;;
        -d|--terraform-dir)
            TERRAFORM_DIR="$2"
            shift 2
            ;;
        -g|--node-rg)
            NODE_RESOURCE_GROUP="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option $1"
            show_help
            ;;
    esac
done

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Set default terraform directory if not provided
if [[ -z "$TERRAFORM_DIR" ]]; then
    TERRAFORM_DIR="$REPO_ROOT/deploy/terraform"
fi

echo -e "${CYAN}==> Discovering Terraform outputs...${NC}"
cd "$TERRAFORM_DIR"

# Get terraform outputs
PIP=$(terraform output -raw ingress_ip 2>/dev/null || echo "")
PIP_NAME=$(terraform output -raw ingress_ip_name 2>/dev/null || echo "")
if [[ -z "$NODE_RESOURCE_GROUP" ]]; then
    NODE_RESOURCE_GROUP=$(terraform output -raw aks_node_resource_group 2>/dev/null || echo "")
fi
AKS_NAME=$(terraform output -raw aks_name 2>/dev/null || echo "")
RG_NAME=$(terraform output -raw resource_group 2>/dev/null || echo "")

cd - > /dev/null

if [[ -z "$PIP" || -z "$PIP_NAME" || -z "$NODE_RESOURCE_GROUP" ]]; then
    echo -e "${RED}Error: Failed to read Terraform outputs (ingress_ip, ingress_ip_name, aks_node_resource_group).${NC}"
    exit 1
fi

echo -e "${YELLOW}IP: $PIP${NC}"
echo -e "${YELLOW}PIP Name: $PIP_NAME${NC}"
echo -e "${YELLOW}AKS Node RG: $NODE_RESOURCE_GROUP${NC}"
if [[ -n "$AKS_NAME" && -n "$RG_NAME" ]]; then
    echo -e "${YELLOW}AKS: $AKS_NAME (RG: $RG_NAME)${NC}"
fi

echo -e "${CYAN}==> Ensuring kubeconfig is set for AKS...${NC}"
# Check if kubectl can reach the cluster
NEED_KUBE=true
if kubectl version --short >/dev/null 2>&1; then
    NEED_KUBE=false
fi

if [[ "$NEED_KUBE" == true && -n "$AKS_NAME" && -n "$RG_NAME" ]]; then
    # Check if logged into Azure
    if ! az account show >/dev/null 2>&1; then
        echo -e "${YELLOW}Azure login required (device code)...${NC}"
        az login --use-device-code
    fi
    echo "Fetching AKS kubeconfig for RG '$RG_NAME', AKS '$AKS_NAME'..."
    az aks get-credentials -g "$RG_NAME" -n "$AKS_NAME" --overwrite-existing
fi

# Re-check cluster reachability
if ! kubectl version --short >/dev/null 2>&1; then
    echo -e "${RED}Error: Kubernetes cluster unreachable. Ensure kubeconfig is set (az aks get-credentials) and network connectivity.${NC}"
    exit 1
fi

# Check for values file
VALUES_PATH="$REPO_ROOT/deploy/tls/40-ingress-nginx-values.yaml"
USE_VALUES=false
if [[ -f "$VALUES_PATH" ]]; then
    USE_VALUES=true
else
    echo -e "${YELLOW}Warning: Values file not found at $VALUES_PATH; proceeding with --set flags only.${NC}"
fi

# Ensure chart repo is present
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

# Build helm command
HELM_ARGS=(
    "upgrade" "--install" "$RELEASE" "ingress-nginx/ingress-nginx"
    "--namespace" "$NAMESPACE" "--create-namespace"
)

if [[ "$USE_VALUES" == true ]]; then
    HELM_ARGS+=("-f" "$VALUES_PATH")
fi

HELM_ARGS+=(
    "--set" "controller.service.loadBalancerIP=$PIP"
    "--set" "controller.service.annotations.service\.beta\.kubernetes\.io/azure-pip-name=$PIP_NAME"
    "--set" "controller.service.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-resource-group=$NODE_RESOURCE_GROUP"
    "--set" "controller.ingressClassResource.name=nginx"
    "--set" "controller.ingressClass=nginx"
    "--set" "controller.service.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-protocol=Tcp"
    "--set" "controller.service.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-port=443"
)

echo -e "${CYAN}==> Applying ingress-nginx with static IP binding...${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo "helm ${HELM_ARGS[*]}"
    exit 0
fi

helm "${HELM_ARGS[@]}"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Error: helm upgrade/install failed${NC}"
    exit 1
fi

echo -e "${CYAN}==> Waiting for Service external IP...${NC}"
EXT_IP=""
for i in {1..30}; do
    if EXT_IP=$(kubectl get svc -n "$NAMESPACE" ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null); then
        if [[ -n "$EXT_IP" ]]; then
            echo -e "${GREEN}EXTERNAL-IP: $EXT_IP${NC}"
            break
        fi
    fi
    sleep 5
done

if [[ -z "$EXT_IP" ]]; then
    echo -e "${RED}Error: External IP not assigned yet. Check Azure LB/NSG and Public IP binding.${NC}"
    exit 1
fi

echo -e "${CYAN}==> Configuring load balancer backend pool...${NC}"
if NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null); then
    if [[ -n "$NODE_IPS" ]]; then
        LB_NAME="kubernetes"
        POOL_NAME="kubernetes"
        
        for NODE_IP in $NODE_IPS; do
            echo "Adding node IP $NODE_IP to backend pool..."
            ADDRESS_ID="node-$NODE_IP"
            if az network lb address-pool address add --resource-group "$NODE_RESOURCE_GROUP" --lb-name "$LB_NAME" --pool-name "$POOL_NAME" --name "$ADDRESS_ID" --ip-address "$NODE_IP" >/dev/null 2>&1; then
                echo -e "${GREEN}Added $NODE_IP to backend pool${NC}"
            else
                echo -e "${YELLOW}Node IP $NODE_IP may already be in backend pool or error occurred${NC}"
            fi
        done
    else
        echo -e "${YELLOW}Warning: No node IPs found${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Failed to configure backend pool${NC}"
fi

echo -e "${CYAN}==> Configuring NSG rules...${NC}"
if NSG_NAME=$(az network nsg list --resource-group "$NODE_RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null); then
    if [[ -n "$NSG_NAME" ]]; then
        echo "Found NSG: $NSG_NAME"
        
        # Check if HTTP/HTTPS rule already exists
        if EXISTING_RULE=$(az network nsg rule list --resource-group "$NODE_RESOURCE_GROUP" --nsg-name "$NSG_NAME" --query "[?name=='allow-http-https']" -o json 2>/dev/null); then
            if [[ "$EXISTING_RULE" == "[]" || -z "$EXISTING_RULE" ]]; then
                echo "Creating NSG rule to allow HTTP/HTTPS traffic..."
                if az network nsg rule create --resource-group "$NODE_RESOURCE_GROUP" --nsg-name "$NSG_NAME" --name "allow-http-https" --priority 300 --access Allow --direction Inbound --protocol Tcp --source-address-prefixes Internet --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 80 443 >/dev/null 2>&1; then
                    echo -e "${GREEN}NSG rule created successfully${NC}"
                else
                    echo -e "${YELLOW}Warning: Failed to create NSG rule${NC}"
                fi
            else
                echo -e "${YELLOW}NSG rule already exists${NC}"
            fi
        else
            echo -e "${YELLOW}Warning: Could not check existing NSG rules${NC}"
        fi
    else
        echo -e "${YELLOW}Warning: Could not find NSG in resource group $NODE_RESOURCE_GROUP${NC}"
    fi
else
    echo -e "${YELLOW}Warning: Failed to configure NSG rules${NC}"
fi

echo -e "${GREEN}==> Setup complete!${NC}"
echo -e "${GREEN}External IP: $EXT_IP${NC}"
echo -e "${CYAN}Test connectivity: curl -I http://$EXT_IP${NC}"
