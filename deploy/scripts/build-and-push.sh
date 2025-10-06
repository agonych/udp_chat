#!/bin/bash

set -e

# Optional: pass tag as first argument, otherwise use TAG env or default to latest
TAG="${1:-${TAG:-latest}}"

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

# Build and push
echo "==> Building server"
docker build -t "$ACR_LOGIN_SERVER/server:$TAG" "$REPO_ROOT/server"
docker push "$ACR_LOGIN_SERVER/server:$TAG"

echo "==> Building connector"
docker build -t "$ACR_LOGIN_SERVER/connector:$TAG" "$REPO_ROOT/connector"
docker push "$ACR_LOGIN_SERVER/connector:$TAG"

echo "==> Building client"
docker build -t "$ACR_LOGIN_SERVER/client:$TAG" "$REPO_ROOT/client"
docker push "$ACR_LOGIN_SERVER/client:$TAG"

echo
echo "==> All images built and pushed successfully!"
echo "You can now deploy with:"
echo "  ./deploy/scripts/deploy.sh -e testing -w"
