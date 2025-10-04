#!/bin/bash

# Build and Push Docker Images Script for Linux
# Usage: ./build-and-push.sh [-h]

set -e

# Default values
HELP=false
TAG="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to show help
show_help() {
    echo "Build and Push Docker Images Script"
    echo ""
    echo "Usage:"
    echo "  ./build-and-push.sh [-h]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "This script builds and pushes all Docker images to Azure Container Registry."
    echo "Images built:"
    echo "  - server (UDP chat server)"
    echo "  - connector (WebSocket connector)"
    echo "  - client (Frontend application)"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
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

if [[ "$HELP" == true ]]; then
    show_help
fi

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ACR configuration
ACR_NAME="udpchatacr"
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

echo -e "${CYAN}==> Building and pushing images to $ACR_LOGIN_SERVER${NC}"
echo "Tag: $TAG"

# Login to ACR
echo -e "${CYAN}==> Logging into ACR${NC}"
if az acr login --name "$ACR_NAME"; then
    echo -e "${GREEN}Login Succeeded${NC}"
else
    echo -e "${RED}Failed to login to ACR${NC}"
    exit 1
fi

# Function to build and push image
build_and_push() {
    local component="$1"
    local dockerfile="$2"
    local context="$3"
    
    echo -e "${CYAN}==> Building $component image${NC}"
    
    # Build the image
    if docker build -t "$ACR_LOGIN_SERVER/$component:$TAG" -f "$dockerfile" "$context"; then
        echo -e "${GREEN}Successfully built $component image${NC}"
    else
        echo -e "${RED}Failed to build $component image${NC}"
        exit 1
    fi
    
    # Push the image
    echo -e "${CYAN}==> Pushing $component image${NC}"
    if docker push "$ACR_LOGIN_SERVER/$component:$TAG"; then
        echo -e "${GREEN}Successfully pushed $component image${NC}"
    else
        echo -e "${RED}Failed to push $component image${NC}"
        exit 1
    fi
}

# Build and push server image
build_and_push "server" "$REPO_ROOT/server/Dockerfile" "$REPO_ROOT/server"

# Build and push connector image
build_and_push "connector" "$REPO_ROOT/connector/Dockerfile" "$REPO_ROOT/connector"

# Build and push client image
build_and_push "client" "$REPO_ROOT/client/Dockerfile" "$REPO_ROOT/client"

echo -e "\n${GREEN}==> All images built and pushed successfully!${NC}"
echo "You can now deploy with:"
echo "  ./deploy.sh -e testing"
echo "  ./deploy.sh -e blue"
echo "  ./deploy.sh -e green"
echo "  ./deploy.sh -e both"
