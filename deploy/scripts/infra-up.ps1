#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

# Get the directory of the current script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TfDir = Join-Path $ScriptDir "..\terraform"

# Change to the Terraform directory and run init and apply
Push-Location $TfDir

# Initialize and apply Terraform configuration
terraform init -upgrade

# Phase 1: build base Azure infra (AKS/ACR/PG/IP), skip Kubernetes/Helm
terraform apply -auto-approve -input=false -var enable_k8s=false

# Phase 2: deploy Kubernetes/Helm/DNS now that AKS API is ready
terraform apply -auto-approve -input=false -var enable_k8s=true

# Phase 3: create ClusterIssuer after CRDs are present
terraform apply -auto-approve -input=false -var enable_k8s=true -var enable_clusterissuer=true

Write-Host "OK: Infra is up (base + k8s)"

# Return to the original directory
Pop-Location
