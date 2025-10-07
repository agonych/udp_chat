#requires -version 5.1
param(
    [Parameter(Mandatory=$false)]
    [string]$Tag = "latest",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("server", "connector", "client", "all")]
    [string]$Service = "all",
    
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Host "Build and Push Script for UDP Chat Application"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\deploy\scripts\build-and-push.ps1 [-Tag <tag>] [-Service <service>] [-Help]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -Tag <tag>        Docker image tag (default: latest)"
    Write-Host "  -Service <service> Service to build (default: all)"
    Write-Host "  -Help             Show this help message"
    Write-Host ""
    Write-Host "Services:"
    Write-Host "  server            UDP chat server"
    Write-Host "  connector         WebSocket connector"
    Write-Host "  client            Frontend application"
    Write-Host "  all               All services (default)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\deploy\scripts\build-and-push.ps1"
    Write-Host "  .\deploy\scripts\build-and-push.ps1 -Tag v1.2.3 -Service server"
    Write-Host "  .\deploy\scripts\build-and-push.ps1 -Service client"
    exit 0
}

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
Write-Host "Service: $Service"

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

# Build and push based on service parameter
if ($Service -eq "all" -or $Service -eq "server") {
    Write-Host "==> Building server image"
    docker build -t "$acrLoginServer/server:$Tag" ./server
    docker push "$acrLoginServer/server:$Tag"
}

if ($Service -eq "all" -or $Service -eq "connector") {
    Write-Host "==> Building connector image"
    docker build -t "$acrLoginServer/connector:$Tag" ./connector
    docker push "$acrLoginServer/connector:$Tag"
}

if ($Service -eq "all" -or $Service -eq "client") {
    Write-Host "==> Building client image"
    docker build -t "$acrLoginServer/client:$Tag" ./client
    docker push "$acrLoginServer/client:$Tag"
}

Write-Host "`n==> Build and push completed successfully!"
if ($Service -eq "all") {
    Write-Host "All services built and pushed."
} else {
    Write-Host "Service '$Service' built and pushed."
}
Write-Host "You can now deploy with:"
Write-Host "  .\deploy\scripts\deploy.ps1 -Environment testing"