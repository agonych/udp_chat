#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

# Get the directory of the current script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TfDir = Join-Path $ScriptDir "..\terraform"

# Change to the Terraform directory and run init and apply
Push-Location $TfDir

# Initialize and apply Terraform configuration
terraform init -upgrade
terraform apply -auto-approve
Write-Host "OK: Infra is up"

# Return to the original directory
Pop-Location
