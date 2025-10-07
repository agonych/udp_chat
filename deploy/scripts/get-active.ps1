#!/usr/bin/env pwsh
param([switch]$Help)

if ($Help) {
  Write-Host "Get active colour for www (blue|green)"; exit 0
}

$ErrorActionPreference = 'Stop'
$ns = 'udpchat-prod'

try {
  $json = kubectl -n $ns get ingress -l app.kubernetes.io/instance=udpchat-www -o json | ConvertFrom-Json
  if (-not $json.items -or $json.items.Count -eq 0) {
    Write-Host "unknown"; exit 0
  }
  $color = $json.items[0].metadata.labels.'app.kubernetes.io/color'
  if (-not $color) { Write-Host "unknown" } else { Write-Host $color }
} catch {
  Write-Host "unknown"
}


