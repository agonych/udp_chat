#!/usr/bin/env pwsh
param([switch]$Help)

if ($Help) {
  Write-Host @"
Authenticate kubectl to AKS cluster

Usage:
  .\deploy\scripts\aks-login.ps1

This script reads AKS cluster info from Terraform outputs and configures kubectl.
Prerequisites: 
  - Run 'az login' first
  - Run '.\deploy\scripts\infra-up.ps1' to create the cluster
"@
  exit 0
}

$ErrorActionPreference = 'Stop'

# Get script directory and resolve paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir '..\..')
$TfDir = Resolve-Path (Join-Path $RepoRoot 'deploy\terraform')

Write-Host "AKS Login Script" -ForegroundColor Cyan

# Read Terraform outputs for AKS
$AksClusterName = ''
$AksResourceGroup = ''
try {
  Push-Location $TfDir
  $AksClusterName = terraform output -raw aks_name 2>$null
  $AksResourceGroup = terraform output -raw resource_group 2>$null
} catch {
  Write-Host "Error: Could not read Terraform outputs" -ForegroundColor Red
  Write-Host "Make sure you've run: .\deploy\scripts\infra-up.ps1" -ForegroundColor Yellow
  exit 1
}
finally { Pop-Location }

if (-not $AksClusterName -or -not $AksResourceGroup) {
  Write-Host "Error: Could not get AKS cluster information from Terraform" -ForegroundColor Red
  Write-Host "Make sure infrastructure is deployed: .\deploy\scripts\infra-up.ps1" -ForegroundColor Yellow
  exit 1
}

Write-Host "Cluster: $AksClusterName" -ForegroundColor Cyan
Write-Host "Resource Group: $AksResourceGroup" -ForegroundColor Cyan
Write-Host ""

# Get credentials
Write-Host "Getting AKS credentials from Azure..." -ForegroundColor Yellow

# Temporarily allow errors for this command
$prevErrorPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'

az aks get-credentials --resource-group $AksResourceGroup --name $AksClusterName --overwrite-existing 2>&1 | Out-Null
$credResult = $LASTEXITCODE

$ErrorActionPreference = $prevErrorPref

if ($credResult -ne 0) {
  Write-Host "Error: Failed to get AKS credentials" -ForegroundColor Red
  Write-Host "Make sure you're logged in: az login" -ForegroundColor Yellow
  exit 1
}

Write-Host "[OK] Credentials configured successfully" -ForegroundColor Green

# Test connection
Write-Host ""
Write-Host "Testing connection to cluster..." -ForegroundColor Yellow
try {
  $nodes = kubectl get nodes --request-timeout=5s 2>$null
  if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Successfully connected to AKS cluster!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Cluster nodes:" -ForegroundColor Cyan
    kubectl get nodes
    Write-Host ""
    Write-Host "Current context:" -ForegroundColor Cyan
    kubectl config current-context
  } else {
    Write-Host "Warning: Credentials configured but cannot connect to cluster" -ForegroundColor Yellow
    Write-Host "Check your network connection or VPN settings" -ForegroundColor Yellow
    exit 1
  }
} catch {
  Write-Host "Warning: Cannot connect to cluster" -ForegroundColor Yellow
  Write-Host "Check your network connection or VPN settings" -ForegroundColor Yellow
  exit 1
}

Write-Host ""
Write-Host "[OK] You are now authenticated to AKS. You can run deployment scripts." -ForegroundColor Green

