#!/usr/bin/env pwsh
param([switch]$Help)

if ($Help) {
  Write-Host "Get active colour for www (blue|green)"; exit 0
}

$ErrorActionPreference = 'Stop'
$ns = 'udpchat-prod'

try {
  # Read from configmap-active
  $color = kubectl -n $ns get configmap udpchat-www-active -o jsonpath='{.data.active}' 2>$null
  if ($color) {
    Write-Host $color.Trim()
  } else {
    # Default to green if www not deployed yet
    Write-Host "green"
  }
} catch {
  Write-Host "green"
}


