#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

# Get the directory of the current script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TfDir = Join-Path $ScriptDir "..\terraform"

# Change to the Terraform directory and run destroy
Push-Location $TfDir

# Destroy Terraform-managed infrastructure
terraform destroy -auto-approve
Write-Host "OK: Infra is down"

# Return to the original directory
Pop-Location
