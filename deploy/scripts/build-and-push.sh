#!/bin/bash

set -e

# Parse arguments
TAG="latest"
SERVICE="all"

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        *)
            # If it's not a flag, treat as tag (backward compatibility)
            TAG="$1"
            shift
            ;;
    esac
done

# Validate service parameter
if [[ "$SERVICE" != "server" && "$SERVICE" != "connector" && "$SERVICE" != "client" && "$SERVICE" != "all" ]]; then
    echo "Error: Invalid service '$SERVICE'. Must be one of: server, connector, client, all"
    echo "Usage: $0 [-t|--tag TAG] [-s|--service SERVICE]"
    exit 1
fi

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TF_DIR="$REPO_ROOT/deploy/terraform"

# Fetch ACR login server from Terraform outputs
pushd "$TF_DIR" >/dev/null
ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server 2>/dev/null || true)
popd >/dev/null
if [[ -z "$ACR_LOGIN_SERVER" ]]; then
  echo "ACR login server not found from Terraform outputs. Run terraform apply first."
  exit 1
fi
ACR_NAME="${ACR_LOGIN_SERVER%%.*}"

echo "==> Building and pushing images to $ACR_LOGIN_SERVER"
echo "Tag: $TAG"
echo "Service: $SERVICE"

# Verify Docker CLI and daemon
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found. Install/start Docker and retry."
  exit 1
fi
if ! docker version >/dev/null 2>&1; then
  echo "Docker daemon not reachable. Start Docker and retry."
  exit 1
fi

# Login to ACR
echo "==> Logging into ACR"
az acr login --name "$ACR_NAME"

# Build and push based on service parameter
if [[ "$SERVICE" == "all" || "$SERVICE" == "server" ]]; then
    echo "==> Building server"
    docker build -t "$ACR_LOGIN_SERVER/server:$TAG" "$REPO_ROOT/server"
    docker push "$ACR_LOGIN_SERVER/server:$TAG"
fi

if [[ "$SERVICE" == "all" || "$SERVICE" == "connector" ]]; then
    echo "==> Building connector"
    docker build -t "$ACR_LOGIN_SERVER/connector:$TAG" "$REPO_ROOT/connector"
    docker push "$ACR_LOGIN_SERVER/connector:$TAG"
fi

if [[ "$SERVICE" == "all" || "$SERVICE" == "client" ]]; then
    echo "==> Building client"
    docker build -t "$ACR_LOGIN_SERVER/client:$TAG" "$REPO_ROOT/client"
    docker push "$ACR_LOGIN_SERVER/client:$TAG"
fi

echo
echo "==> Build and push completed successfully!"
if [[ "$SERVICE" == "all" ]]; then
    echo "All services built and pushed."
else
    echo "Service '$SERVICE' built and pushed."
fi
echo "You can now deploy with:"
echo "  ./deploy/scripts/deploy.sh -e testing -w"
