#!/bin/bash

# UDP Chat Removal Script for Linux
# Usage: ./remove.sh -e <environment> [-h]

set -e

# Default values
ENVIRONMENT=""
HELP=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to show help
show_help() {
    echo "UDP Chat Removal Script"
    echo ""
    echo "Usage:"
    echo "  ./remove.sh -e testing"
    echo "  ./remove.sh -e blue|green|both|www|active|inactive"
    echo ""
    echo "Options:"
    echo "  -e, --environment    Environment to remove (testing|blue|green|both|www|active|inactive)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Notes:"
    echo "  - testing => removes udpchat-testing release from udpchat-testing namespace"
    echo "  - blue/green/www => removes specific release from udpchat-prod namespace"
    echo "  - both => removes both blue and green releases from udpchat-prod namespace"
    echo "  - active => removes the currently active color release (green)"
    echo "  - inactive => removes the currently inactive color release (blue)"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
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
    testing|blue|green|both|www|active|inactive)
        ;;
    *)
        echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'${NC}"
        echo "Valid options: testing, blue, green, both, www, active, inactive"
        exit 1
        ;;
esac

echo -e "${CYAN}UDP Chat Removal Script${NC}"
echo "Environment: $ENVIRONMENT"

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
    www)
        NAMESPACE="udpchat-prod"
        RELEASE_NAME="udpchat-www"
        ;;
    both)
        NAMESPACE="udpchat-prod"
        RELEASE_NAMES=("udpchat-blue" "udpchat-green")
        ;;
    active)
        NAMESPACE="udpchat-prod"
        RELEASE_NAME="udpchat-green"  # Currently active color
        echo -e "${RED}WARNING: You are removing the ACTIVE environment (green)!${NC}"
        echo -e "${RED}This will take down production traffic at www.chat.kudriavcev.com${NC}"
        read -p "Are you sure you want to continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo -e "${YELLOW}Operation cancelled.${NC}"
            exit 0
        fi
        ;;
    inactive)
        NAMESPACE="udpchat-prod"
        RELEASE_NAME="udpchat-blue"   # Currently inactive color
        ;;
esac

echo "Namespace: $NAMESPACE"

# Function to remove release
remove_release() {
    local release="$1"
    echo -e "${YELLOW}Removing release: $release${NC}"
    if helm uninstall "$release" -n "$NAMESPACE"; then
        echo -e "${GREEN}Successfully removed $release${NC}"
        return 0
    else
        echo -e "${RED}Failed to remove $release${NC}"
        return 1
    fi
}

# Remove releases
if [[ "$ENVIRONMENT" == "both" ]]; then
    echo -e "${YELLOW}Removing both blue and green deployments...${NC}"
    for release in "${RELEASE_NAMES[@]}"; do
        remove_release "$release"
    done
else
    remove_release "$RELEASE_NAME"
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
fi

echo -e "\n${CYAN}Verifying removal...${NC}"
if kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null; then
    echo -e "${YELLOW}Remaining pods in namespace:${NC}"
    kubectl get pods -n "$NAMESPACE"
else
    echo -e "${GREEN}No pods remaining in namespace${NC}"
fi

echo -e "\n${GREEN}Removal completed!${NC}"
