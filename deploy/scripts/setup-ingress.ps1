param(
  [string]$Namespace = "ingress-nginx",
  [string]$Release = "ingress-nginx",
  [string]$TerraformDir = "",
  [string]$NodeResourceGroup = "",
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

# Resolve repo-relative paths robustly
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir '..\..')
if (-not $TerraformDir -or $TerraformDir -eq '') { $TerraformDir = Resolve-Path (Join-Path $RepoRoot 'deploy\terraform') }

Write-Host "==> Discovering Terraform outputs..." -ForegroundColor Cyan
Push-Location $TerraformDir
try {
  $pip = (terraform output -raw ingress_ip) 2>$null
  $pipName = (terraform output -raw ingress_ip_name) 2>$null
  if (-not $NodeResourceGroup) { $NodeResourceGroup = (terraform output -raw aks_node_resource_group) }
  $aksName = (terraform output -raw aks_name) 2>$null
  $rgName  = (terraform output -raw resource_group) 2>$null
} finally { Pop-Location }

if (-not $pip -or -not $pipName -or -not $NodeResourceGroup) {
  Write-Error "Failed to read Terraform outputs (ingress_ip, ingress_ip_name, aks_node_resource_group)."
  exit 1
}

Write-Host "IP: $pip" -ForegroundColor Yellow
Write-Host "PIP Name: $pipName" -ForegroundColor Yellow
Write-Host "AKS Node RG: $NodeResourceGroup" -ForegroundColor Yellow
if ($aksName -and $rgName) { Write-Host "AKS: $aksName (RG: $rgName)" -ForegroundColor Yellow }

Write-Host "==> Ensuring kubeconfig is set for AKS..." -ForegroundColor Cyan
# If kubectl cannot reach the cluster, attempt az login and az aks get-credentials
$needKube = $true
try {
  kubectl version --short 2>$null | Out-Null
  $needKube = $false
} catch { $needKube = $true }

if ($needKube -and $aksName -and $rgName) {
  try { az account show | Out-Null } catch { }
  if (-not (az account show 2>$null)) {
    Write-Host "Azure login required (device code)..." -ForegroundColor Yellow
    az login --use-device-code | Out-Null
  }
  Write-Host ("Fetching AKS kubeconfig for RG '{0}', AKS '{1}'..." -f $rgName, $aksName)
  az aks get-credentials -g $rgName -n $aksName --overwrite-existing | Out-Null
}

# Re-check cluster reachability
try {
  kubectl version --short | Out-Null
} catch {
  throw "Kubernetes cluster unreachable. Ensure kubeconfig is set (az aks get-credentials) and network connectivity."
}

# Include pinned defaults file if present; otherwise continue with flags only
$valuesPath = Join-Path $RepoRoot 'deploy\tls\40-ingress-nginx-values.yaml'
$useValues = Test-Path $valuesPath

# Ensure chart repo is present
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>$null | Out-Null
helm repo update | Out-Null

$args = @(
  "upgrade","--install",$Release,"ingress-nginx/ingress-nginx",
  "--namespace",$Namespace,"--create-namespace"
)
if ($useValues) { $args += @("-f",$valuesPath) } else { Write-Warning "Values file not found at $valuesPath; proceeding with --set flags only." }
$args += @(
  "--set","controller.service.loadBalancerIP=$pip",
  "--set","controller.service.annotations.service\.beta\.kubernetes\.io/azure-pip-name=$pipName",
  "--set","controller.service.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-resource-group=$NodeResourceGroup",
  "--set","controller.ingressClassResource.name=nginx",
  "--set","controller.ingressClass=nginx",
  "--set","controller.service.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-protocol=Tcp",
  "--set","controller.service.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-port=443"
)

Write-Host "==> Applying ingress-nginx with static IP binding..." -ForegroundColor Cyan
if ($DryRun) { Write-Host "helm $($args -join ' ')"; exit 0 }
& helm @args

if ($LASTEXITCODE -ne 0) {
  throw "helm upgrade/install failed"
}

Write-Host "==> Waiting for Service external IP..." -ForegroundColor Cyan
for ($i=0; $i -lt 30; $i++) {
  try {
    $svc = kubectl get svc -n $Namespace ingress-nginx-controller -o json 2>$null | ConvertFrom-Json
    $ext = $svc.status.loadBalancer.ingress[0].ip
    if ($ext) { Write-Host "EXTERNAL-IP: $ext" -ForegroundColor Green; break }
  } catch {
    # service may not exist yet
  }
  Start-Sleep 5
}

if (-not $ext) { throw "External IP not assigned yet. Check Azure LB/NSG and Public IP binding." }

Write-Host "==> Configuring NSG rules..." -ForegroundColor Cyan
try {
  # Get NSG name
  $nsgName = az network nsg list --resource-group $NodeResourceGroup --query "[0].name" -o tsv
  if ($nsgName) {
    Write-Host "Found NSG: $nsgName"
    
    # Check if HTTP/HTTPS rule already exists
    $existingRule = az network nsg rule list --resource-group $NodeResourceGroup --nsg-name $nsgName --query "[?name=='allow-http-https']" -o json
    if (-not $existingRule -or $existingRule -eq '[]') {
      Write-Host "Creating NSG rule to allow HTTP/HTTPS traffic..."
      az network nsg rule create --resource-group $NodeResourceGroup --nsg-name $nsgName --name "allow-http-https" --priority 300 --access Allow --direction Inbound --protocol Tcp --source-address-prefixes Internet --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 80 443 | Out-Null
      Write-Host "NSG rule created successfully" -ForegroundColor Green
    } else {
      Write-Host "NSG rule already exists" -ForegroundColor Yellow
    }
  } else {
    Write-Host "Warning: Could not find NSG in resource group $NodeResourceGroup" -ForegroundColor Yellow
  }
} catch {
  Write-Host "Warning: Failed to configure NSG rules: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "==> Setup complete!" -ForegroundColor Green
Write-Host "External IP: $ext" -ForegroundColor Green
Write-Host "Test connectivity: Test-NetConnection -ComputerName $ext -Port 80" -ForegroundColor Cyan


