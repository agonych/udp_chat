#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

# Get the directory of the current script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TfDir = Join-Path $ScriptDir "..\terraform"

# Change to the Terraform directory and run destroy
Push-Location $TfDir

# Two-phase destroy: first remove Kubernetes/Helm/DNS, then base Azure infra

# Phase 1: destroy k8s/helm/dns (including ClusterIssuer)
terraform destroy -auto-approve -input=false -var enable_k8s=true -var enable_clusterissuer=true

# Phase 2: destroy base Azure infra (AKS/ACR/PG/IP)
terraform destroy -auto-approve -input=false -var enable_k8s=false

Write-Host "OK: Infra is down (k8s + base)"

# Return to the original directory
Pop-Location
