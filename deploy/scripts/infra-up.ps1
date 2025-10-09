#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

# Get the directory of the current script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TfDir = Join-Path $ScriptDir "..\terraform"

# Change to the Terraform directory and run init and apply
Push-Location $TfDir

# Initialize and apply Terraform configuration
terraform init -upgrade

# Three-phase apply to handle dependencies properly
# Phase 1: create base Azure infra
terraform apply -auto-approve -input=false
# Phase 2: create Kubernetes/Helm/DNS
terraform apply -auto-approve -input=false -var enable_k8s=true
# Phase 3: create ClusterIssuer
terraform apply -auto-approve -input=false -var enable_k8s=true -var enable_clusterissuer=true

Write-Host "Infrastructure deployment complete." -ForegroundColor Green

# Return to the original directory
Pop-Location
