#!/usr/bin/env bash
set -e

NS=udpchat-prod

# Read from configmap-active
ACTIVE=$(kubectl -n "$NS" get configmap udpchat-www-active -o jsonpath='{.data.active}' 2>/dev/null || true)
if [[ -n "$ACTIVE" ]]; then
  echo "$ACTIVE"
else
  # Default to green if www not deployed yet
  echo "green"
fi


