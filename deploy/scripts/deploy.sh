#!/bin/bash

# UDP Chat Deployment Script for Linux
# Usage: ./deploy.sh -e <environment> [-w] [-h]

set -e

# Default values
ENVIRONMENT=""
TAG="latest"
WAIT=false
HELP=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to show help
show_help() {
    echo "UDP Chat Deployment Script"
    echo ""
    echo "Usage:"
    echo "  ./deploy.sh -e testing [-t <tag>] [-w]"
    echo "  ./deploy.sh -e blue|green|both|active|inactive [-t <tag>] [-w]"
    echo ""
    echo "Options:"
    echo "  -e, --environment    Environment to deploy (testing|blue|green|both|active|inactive)"
    echo "  -t, --tag           Docker image tag to deploy (default: latest)"
    echo "  -w, --wait          Wait for deployment to complete"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Notes:"
    echo "  - testing => namespace udpchat-testing, uses values.testing.yaml"
    echo "  - blue/green/both => namespace udpchat-prod, uses values.prod.yaml"
    echo "  - active => deploys to currently active color (green)"
    echo "  - inactive => deploys to currently inactive color (blue)"
    echo "  - use -w to wait for deployment completion"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -w|--wait)
            WAIT=true
            shift
            ;;
        -h|--help)
            HELP=true
            shift
            ;;
        *)
            echo "Unknown option $1"
            show_help
            ;;
    esac
done

if [[ "$HELP" == true ]] || [[ -z "$ENVIRONMENT" ]]; then
    show_help
fi

# Validate environment
case "$ENVIRONMENT" in
    testing|blue|green|both|active|inactive)
        ;;
    *)
        echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'${NC}"
        echo "Valid options: testing, blue, green, both, active, inactive"
        exit 1
        ;;
esac

# Get script directory and chart path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHART_DIR="$REPO_ROOT/deploy/helm/chart"

# Read Terraform outputs for ACR and DNS
TF_DIR="$REPO_ROOT/deploy/terraform"
if [[ -d "$TF_DIR" ]]; then
    pushd "$TF_DIR" >/dev/null
    ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server 2>/dev/null || true)
    DNS_ZONE_NAME=$(terraform output -raw dns_zone_name 2>/dev/null || true)
    popd >/dev/null
fi

# Determine namespace and release names
case "$ENVIRONMENT" in
    testing)
        NAMESPACE="udpchat-testing"
        RELEASE_NAME="udpchat-testing"
        ;;
    blue)
        NAMESPACE="udpchat-prod"
        RELEASE_NAME="udpchat-blue"
        ;;
    green)
        NAMESPACE="udpchat-prod"
        RELEASE_NAME="udpchat-green"
        ;;
    both)
        NAMESPACE="udpchat-prod"
        RELEASE_NAME="udpchat"
        ;;
    active)
        NAMESPACE="udpchat-prod"
        RELEASE_NAME="udpchat-green"
        ;;
    inactive)
        NAMESPACE="udpchat-prod"
        RELEASE_NAME="udpchat-blue"
        ;;
esac

# Function to deploy with Helm
helm_deploy() {
    local release="$1"
    local namespace="$2"
    local target="$3"
    local values_file="$4"
    
    local helm_args=("upgrade" "--install" "$release" "$CHART_DIR" "--namespace" "$namespace" "-f" "$values_file" "--set" "deployTarget=$target")
    
    # Set image registries from Terraform outputs if available
    if [[ -n "$ACR_LOGIN_SERVER" ]]; then
        helm_args+=("--set" "images.server=$ACR_LOGIN_SERVER/server:$TAG")
        helm_args+=("--set" "images.connector=$ACR_LOGIN_SERVER/connector:$TAG")
        helm_args+=("--set" "images.client=$ACR_LOGIN_SERVER/client:$TAG")
    fi

    # Set domain from Terraform DNS zone, if available
    if [[ -n "$DNS_ZONE_NAME" ]]; then
        helm_args+=("--set" "domain=$DNS_ZONE_NAME")
    fi
    
    if [[ "$WAIT" == true ]]; then
        helm_args+=("--wait" "--timeout" "10m")
    fi
    
    echo "Running: helm ${helm_args[*]}"
    helm "${helm_args[@]}"
}

echo -e "${CYAN}UDP Chat Deployment Script${NC}"
echo "Environment: $ENVIRONMENT"
echo "Tag: $TAG"
echo "Release: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"

# Ensure namespace exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - > /dev/null

# Apply environment-specific secret if present
if [[ "$ENVIRONMENT" == "testing" ]]; then
    if [[ -f "$CHART_DIR/secret.testing.yaml" ]]; then
        kubectl -n "$NAMESPACE" apply -f "$CHART_DIR/secret.testing.yaml" >/dev/null || true
    fi
else
    if [[ -f "$CHART_DIR/secret.yaml" ]]; then
        kubectl -n "$NAMESPACE" apply -f "$CHART_DIR/secret.yaml" >/dev/null || true
    fi
fi

# Deploy based on environment
if [[ "$ENVIRONMENT" == "testing" ]]; then
    helm_deploy "$RELEASE_NAME" "$NAMESPACE" "testing" "values.testing.yaml"
elif [[ "$ENVIRONMENT" == "both" ]]; then
    echo "Deploying both blue and green environments..."
    helm_deploy "udpchat-blue" "$NAMESPACE" "blue" "values.prod.yaml"
    helm_deploy "udpchat-green" "$NAMESPACE" "green" "values.prod.yaml"
else
    # Determine current active colour from www ingress label if present
    ACTIVE=$(kubectl -n "$NAMESPACE" get ingress udpchat-www-www -o jsonpath='{.metadata.labels.app\.kubernetes\.io/color}' 2>/dev/null || true)
    if [[ -z "$ACTIVE" ]]; then ACTIVE="green"; fi

    # Map active/inactive dynamically
    case "$ENVIRONMENT" in
        active)
            target="$ACTIVE"
            ;;
        inactive)
            if [[ "$ACTIVE" == "green" ]]; then target="blue"; else target="green"; fi
            ;;
        *)
            target="$ENVIRONMENT"
            ;;
    esac
    # Align release name with target colour
    RELEASE_NAME="udpchat-$target"
    helm_deploy "$RELEASE_NAME" "$NAMESPACE" "$target" "values.prod.yaml"
fi

echo -e "\n${CYAN}Deployment Status:${NC}"
kubectl get pods -n "$NAMESPACE" || true
kubectl get svc -n "$NAMESPACE" || true
kubectl get ingress -n "$NAMESPACE" || true

# Configure NSG rules for testing environment (Azure specific)
if [[ "$ENVIRONMENT" == "testing" ]]; then
    echo -e "\n${CYAN}Configuring NSG rules for ingress access...${NC}"
    if [[ -f "$REPO_ROOT/deploy/terraform" ]]; then
        cd "$REPO_ROOT/deploy/terraform"
        NODE_RG=$(terraform output -raw aks_node_resource_group 2>/dev/null || echo "")
        if [[ -n "$NODE_RG" ]]; then
            echo "Found AKS node resource group: $NODE_RG"
            # Note: NSG configuration would need Azure CLI
            echo "Note: NSG rule configuration requires Azure CLI and appropriate permissions"
        fi
        cd - > /dev/null
    fi
fi

echo -e "\n${GREEN}Deployment completed!${NC}"
