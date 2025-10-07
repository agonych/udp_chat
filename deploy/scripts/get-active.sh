#!/usr/bin/env bash
set -e

NS=udpchat-prod
ACTIVE=$(kubectl -n "$NS" get ingress -l app.kubernetes.io/instance=udpchat-www -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/color}' 2>/dev/null || true)
if [[ -z "$ACTIVE" ]]; then
  echo unknown
else
  echo "$ACTIVE"
fi


