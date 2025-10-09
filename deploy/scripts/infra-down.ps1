#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

# Get the directory of the current script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TfDir = Join-Path $ScriptDir "..\terraform"

# Change to the Terraform directory and run destroy
Push-Location $TfDir

# Two-phase destroy: first remove Kubernetes/Helm/DNS, then base Azure infra
# Phase 1: destroy k8s/helm/dns (including ClusterIssuer) by applying with enable_k8s=false
terraform apply -auto-approve -input=false
# Phase 2: destroy the rest of the infra
terraform destroy -auto-approve -input=false

Write-Host "Infrastructure teardown complete." -ForegroundColor Green

# Return to the original directory
Pop-Location
