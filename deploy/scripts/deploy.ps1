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

# Apply secret file if it exists
$secretFile = if ($Environment -eq 'testing') {
  Join-Path $ChartDir 'secret.testing.yaml'
} else {
  Join-Path $ChartDir 'secret.yaml'
}
$useExistingSecret = Test-Path $secretFile


if ($useExistingSecret) {
  # Ensure namespace exists before applying secret
  kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null
  Write-Host "Found $(Split-Path -Leaf $secretFile) - applying to namespace $Namespace" -ForegroundColor Green
  kubectl -n $Namespace apply -f $secretFile

  # Override to use existing secret instead of auto-creating
  if (-not $Set) { $Set = @() }
  $Set += "existingAppSecret.enabled=true"
  $Set += "appSecret.enabled=false"
}

# Deploy based on environment
if ($Environment -eq 'testing') { # Deploy testing environment
  Invoke-HelmDeploy -Rel $ReleaseName -Ns $Namespace -Target 'testing' -ValuesFile 'values.testing.yaml'
} elseif ($Environment -eq 'both') { # Deploy both blue and green production environments
  foreach ($color in @('blue','green')) {
    $rel = "${ReleaseName}-$color"
    Invoke-HelmDeploy -Rel $rel -Ns $Namespace -Target $color -ValuesFile 'values.prod.yaml'
  }
} else { # Deploy single production environment (blue, green, active, inactive)
  # Determine current active colour from configmap-active
  $ActiveColor = ''
  try {
    $ActiveColor = kubectl -n $Namespace get configmap udpchat-www-active -o jsonpath='{.data.active}' 2>$null
  } catch {}
  if (-not $ActiveColor) { $ActiveColor = 'green' }

  # Map active/inactive to actual colors dynamically
  $Target = switch ($Environment) {
    'active' { $ActiveColor }
    'inactive' { if ($ActiveColor -eq 'green') { 'blue' } else { 'green' } }
    default { $Environment }
  } # Now Target is blue or green

  # Ensure release aligns with target colour
  $ReleaseName = "udpchat-$Target"

  Invoke-HelmDeploy -Rel $ReleaseName -Ns $Namespace -Target $Target -ValuesFile 'values.prod.yaml'
}

Write-Host "\nDeployment Status:" -ForegroundColor Cyan
try {
  kubectl get pods -n $Namespace
  kubectl get svc -n $Namespace
  kubectl get ingress -n $Namespace
} catch { }
