#!/usr/bin/env bash
set -e

ENV="$1"
WAIT=false
if [[ "$2" == "-w" || "$2" == "--wait" ]]; then WAIT=true; fi

if [[ -z "$ENV" || "$ENV" == "-h" || "$ENV" == "--help" ]]; then
  echo "Set active colour for www (blue|green|toggle)"
  echo "Usage: $0 blue|green|toggle [-w]"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CHART_DIR="$REPO_ROOT/deploy/helm/chart"
NS="udpchat-prod"
RELEASE="udpchat-www"

# Detect current colour from configmap-active
CURRENT=$(kubectl -n "$NS" get configmap ${RELEASE}-active -o jsonpath='{.data.active}' 2>/dev/null || true)
if [[ -z "$CURRENT" ]]; then CURRENT="green"; fi

if [[ "$ENV" == "toggle" ]]; then
  NEW_COLOR="green"
  [[ "$CURRENT" == "green" ]] && NEW_COLOR="blue"
else
  NEW_COLOR="$ENV"
fi

echo "Current: $CURRENT -> New: $NEW_COLOR"

args=(upgrade --install "$RELEASE" "$CHART_DIR" \
  --namespace "$NS" \
  -f "$CHART_DIR/values.prod.yaml" \
  --set deployTarget=www \
  --set activeColor="$NEW_COLOR")

if [[ "$WAIT" == true ]]; then args+=(--wait --timeout 10m); fi

helm repo update >/dev/null
helm "${args[@]}"

echo "www now routes to: $NEW_COLOR"

