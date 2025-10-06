#requires -version 5.1
param(
    [Parameter(Mandatory=$false)]
    [string]$Tag = "latest"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get ACR details from Terraform
$deployRoot = Split-Path -Parent $PSScriptRoot
$tfDir = Join-Path $deployRoot 'terraform'

Push-Location $tfDir
$acrLoginServer = terraform output -raw acr_login_server
Pop-Location

if (-not $acrLoginServer) {
    throw "Could not get ACR login server from Terraform output"
}

Write-Host "==> Building and pushing images to $acrLoginServer"
Write-Host "Tag: $Tag"

# Verify Docker CLI and daemon availability early
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker CLI not found. Please install Docker Desktop and ensure 'docker' is on PATH."
    exit 1
}
try {
    docker version | Out-Null
} catch {
    Write-Error "Docker daemon not reachable. Start Docker Desktop and retry. Details: $($_.Exception.Message)"
    exit 1
}

# Login to ACR
Write-Host "==> Logging into ACR"
az acr login --name $acrLoginServer.Split('.')[0]

# Build and push server
Write-Host "==> Building server image"
docker build -t "$acrLoginServer/server:$Tag" ./server
docker push "$acrLoginServer/server:$Tag"

# Build and push connector
Write-Host "==> Building connector image"
docker build -t "$acrLoginServer/connector:$Tag" ./connector
docker push "$acrLoginServer/connector:$Tag"

# Build and push client
Write-Host "==> Building client image"
docker build -t "$acrLoginServer/client:$Tag" ./client
docker push "$acrLoginServer/client:$Tag"

Write-Host "`n==> All images built and pushed successfully!"
Write-Host "You can now deploy with:"
Write-Host "  .\deploy\scripts\deploy-env.ps1 -Environment testing"