param(
    [ValidateSet("testing","blue","green","both","active","inactive")]
    [string]$Environment,

  [ValidateSet("active","inactive","both")]
  [string]$ColorMode = "both",

  [string]$ReleaseName,

  [string]$Tag = "latest",

  [string[]]$Set,           # pass-through extra --set key=value entries
  [switch]$Wait,
  [switch]$DryRun,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help -or -not $Environment) {
  Write-Host @"
UDP Chat Deployment Script

Usage:
  .\deploy\scripts\deploy.ps1 -Environment testing [-Tag <tag>] [-Wait]
  .\deploy\scripts\deploy.ps1 -Environment blue|green|both|active|inactive [-Tag <tag>] [-Wait]

Options:
  -Environment    Environment to deploy (testing|blue|green|both|active|inactive)
  -Tag           Docker image tag to deploy (default: latest)
  -Wait          Wait for deployment to complete
  -Help          Show this help message

Notes:
  - testing => namespace udpchat-testing, uses values.testing.yaml
  - blue/green/both => namespace udpchat-prod, uses values.prod.yaml
  - active => deploys to currently active color (green)
  - inactive => deploys to currently inactive color (blue)
  - use -Set key=value to pass extra --set overrides (can be repeated)
"@
  exit 0
}

# Resolve repo root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir '..\..')
$ChartDir  = Resolve-Path (Join-Path $RepoRoot 'deploy\helm\chart')

# Terraform outputs for ACR and DNS
$TfDir = Resolve-Path (Join-Path $RepoRoot 'deploy\terraform')
$AcrLoginServer = ''
$DnsZoneName = ''
try {
  Push-Location $TfDir
  $AcrLoginServer = terraform output -raw acr_login_server 2>$null
  $DnsZoneName = terraform output -raw dns_zone_name 2>$null
} catch {}
finally { Pop-Location }

# Namespaces
switch ($Environment) {
  'testing' { $Namespace = 'udpchat-testing'; if (-not $ReleaseName) { $ReleaseName = 'udpchat-testing' } }
  'blue' { $Namespace = 'udpchat-prod'; if (-not $ReleaseName) { $ReleaseName = 'udpchat-blue' } }
  'green' { $Namespace = 'udpchat-prod'; if (-not $ReleaseName) { $ReleaseName = 'udpchat-green' } }
  'both' { $Namespace = 'udpchat-prod'; if (-not $ReleaseName) { $ReleaseName = 'udpchat' } }
  'active' { $Namespace = 'udpchat-prod'; if (-not $ReleaseName) { $ReleaseName = 'udpchat-green' } }
  'inactive' { $Namespace = 'udpchat-prod'; if (-not $ReleaseName) { $ReleaseName = 'udpchat-blue' } }
}

# Ensure helm repo is up to date (chart is local, but good to have repos updated)
helm repo update | Out-Null

function Invoke-HelmDeploy {
  param(
    [string]$Rel,
    [string]$Ns,
    [string]$Target,      # testing|blue|green
    [string]$ValuesFile
  )

  $args = @('upgrade','--install',$Rel,$ChartDir,
            '--namespace',$Ns,
            '--create-namespace',
            '-f', (Join-Path $ChartDir $ValuesFile),
            '--set', "deployTarget=$Target")

  # Set image registry/tags from Terraform outputs if available
  if ($AcrLoginServer) {
    $args += @('--set', "images.server=$AcrLoginServer/server:$Tag")
    $args += @('--set', "images.connector=$AcrLoginServer/connector:$Tag")
    $args += @('--set', "images.client=$AcrLoginServer/client:$Tag")
    if ($Target -eq 'testing') {
      $args += @('--set', "testServer.image.repository=$AcrLoginServer/test-server")
      $args += @('--set', "testServer.image.tag=$Tag")
    }
  }

  # Set domain from Terraform DNS zone if available
  if ($DnsZoneName) {
    $args += @('--set', "domain=$DnsZoneName")
  }
  if ($Set) { foreach ($kv in $Set) { $args += @('--set', $kv) } }
  if ($Wait) { $args += @('--wait','--timeout','10m') }

  if ($DryRun) { Write-Host "helm $($args -join ' ')"; return }
  & helm @args
}

Write-Host "UDP Chat Deployment Script" -ForegroundColor Cyan
Write-Host ("Environment: {0}" -f $Environment)
Write-Host ("Release: {0}" -f $ReleaseName)
Write-Host ("Namespace: {0}" -f $Namespace)

# Apply environment-specific secret if present
try {
  if ($Environment -eq 'testing') {
    $st = Join-Path $ChartDir 'secret.testing.yaml'
    if (Test-Path $st) { kubectl -n $Namespace apply -f $st | Out-Null }
  } else {
    $sp = Join-Path $ChartDir 'secret.yaml'
    if (Test-Path $sp) { kubectl -n $Namespace apply -f $sp | Out-Null }
  }
} catch {}

if ($Environment -eq 'testing') {
  Invoke-HelmDeploy -Rel $ReleaseName -Ns $Namespace -Target 'testing' -ValuesFile 'values.testing.yaml'
} elseif ($Environment -eq 'both') {
  foreach ($color in @('blue','green')) {
    $rel = "${ReleaseName}-$color"
    Invoke-HelmDeploy -Rel $rel -Ns $Namespace -Target $color -ValuesFile 'values.prod.yaml'
  }
} else {
  # Map active/inactive to actual colors
  $Target = switch ($Environment) {
    'active' { 'green' }
    'inactive' { 'blue' }
    default { $Environment }
  }
  Invoke-HelmDeploy -Rel $ReleaseName -Ns $Namespace -Target $Target -ValuesFile 'values.prod.yaml'
}

Write-Host "\nDeployment Status:" -ForegroundColor Cyan
try {
  kubectl get pods -n $Namespace
  kubectl get svc -n $Namespace
  kubectl get ingress -n $Namespace
} catch { }

# Configure NSG rules for ingress access if this is testing environment
if ($Environment -eq 'testing') {
  Write-Host "\nConfiguring NSG rules for ingress access..." -ForegroundColor Cyan
  try {
    # Get AKS node resource group from Terraform outputs
    $TerraformDir = Resolve-Path (Join-Path $RepoRoot 'deploy\terraform')
    Push-Location $TerraformDir
    $NodeRG = terraform output -raw aks_node_resource_group
    Pop-Location
    
    if ($NodeRG) {
      Write-Host "Found AKS node resource group: $NodeRG"
      
      # Get NSG name
      $NsgName = az network nsg list --resource-group $NodeRG --query "[0].name" -o tsv
      if ($NsgName) {
        Write-Host "Found NSG: $NsgName"
        
        # Check if HTTP/HTTPS rule already exists
        $ExistingRule = az network nsg rule list --resource-group $NodeRG --nsg-name $NsgName --query "[?name=='allow-http-https']" -o json
        if (-not $ExistingRule -or $ExistingRule -eq '[]') {
          Write-Host "Creating NSG rule to allow HTTP/HTTPS traffic..."
          az network nsg rule create --resource-group $NodeRG --nsg-name $NsgName --name "allow-http-https" --priority 300 --access Allow --direction Inbound --protocol Tcp --source-address-prefixes Internet --source-port-ranges "*" --destination-address-prefixes "*" --destination-port-ranges 80 443 | Out-Null
          Write-Host "NSG rule created successfully" -ForegroundColor Green
        } else {
          Write-Host "NSG rule already exists" -ForegroundColor Yellow
        }
      } else {
        Write-Host "Warning: Could not find NSG in resource group $NodeRG" -ForegroundColor Yellow
      }
    } else {
      Write-Host "Warning: Could not determine AKS node resource group from Terraform outputs" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "Warning: Failed to configure NSG rules: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}
