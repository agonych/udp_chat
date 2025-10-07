param(
  [ValidateSet("testing","blue","green","both","www","active","inactive")]
  [string]$Environment,

  [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help -or -not $Environment) {
  Write-Host @"
UDP Chat Removal Script

Usage:
  .\deploy\scripts\remove.ps1 -Environment testing
  .\deploy\scripts\remove.ps1 -Environment blue|green|both|www|active|inactive

Notes:
  - testing => removes udpchat-testing release from udpchat-testing namespace
  - blue/green/www => removes specific release from udpchat-prod namespace
  - both => removes both blue and green releases from udpchat-prod namespace
  - active => removes the currently active color release (green)
  - inactive => removes the currently inactive color release (blue)
"@
  exit 0
}

Write-Host "UDP Chat Removal Script" -ForegroundColor Cyan
Write-Host ("Environment: {0}" -f $Environment)

# Determine namespace and release names
switch ($Environment) {
  'testing' { 
    $Namespace = 'udpchat-testing'
    $ReleaseName = 'udpchat-testing'
  }
  'blue' { 
    $Namespace = 'udpchat-prod'
    $ReleaseName = 'udpchat-blue'
  }
  'green' { 
    $Namespace = 'udpchat-prod'
    $ReleaseName = 'udpchat-green'
  }
  'www' { 
    $Namespace = 'udpchat-prod'
    $ReleaseName = 'udpchat-www'
  }
  'both' { 
    $Namespace = 'udpchat-prod'
    $ReleaseNames = @('udpchat-blue', 'udpchat-green')
  }
  'active' { 
    $Namespace = 'udpchat-prod'
    # Detect current active via www ingress label; default green if unknown
    $ActiveColor = ''
    try { $ActiveColor = kubectl -n $Namespace get ingress udpchat-www-www -o jsonpath='{.metadata.labels.app\.kubernetes\.io/color}' 2>$null } catch {}
    if (-not $ActiveColor) { $ActiveColor = 'green' }
    $ReleaseName = "udpchat-$ActiveColor"
    Write-Host "WARNING: You are removing the ACTIVE environment (green)!" -ForegroundColor Red
    Write-Host "This will take down production traffic at www.chat.kudriavcev.info" -ForegroundColor Red
    $confirm = Read-Host "Are you sure you want to continue? (yes/no)"
    if ($confirm -ne "yes") {
      Write-Host "Operation cancelled." -ForegroundColor Yellow
      exit 0
    }
  }
  'inactive' { 
    $Namespace = 'udpchat-prod'
    # Detect current active and compute inactive
    $ActiveColor = ''
    try { $ActiveColor = kubectl -n $Namespace get ingress udpchat-www-www -o jsonpath='{.metadata.labels.app\.kubernetes\.io/color}' 2>$null } catch {}
    if (-not $ActiveColor) { $ActiveColor = 'green' }
    $Inactive = if ($ActiveColor -eq 'green') { 'blue' } else { 'green' }
    $ReleaseName = "udpchat-$Inactive"
  }
}

Write-Host ("Namespace: {0}" -f $Namespace)

if ($Environment -eq 'both') {
  Write-Host "Removing both blue and green deployments..." -ForegroundColor Yellow
  foreach ($release in $ReleaseNames) {
    Write-Host ("Removing release: {0}" -f $release) -ForegroundColor Yellow
    try {
      helm uninstall $release -n $Namespace
      Write-Host ("Successfully removed {0}" -f $release) -ForegroundColor Green
    } catch {
      Write-Host ("Failed to remove {0}: {1}" -f $release, $_.Exception.Message) -ForegroundColor Red
    }
  }
} else {
  Write-Host ("Removing release: {0}" -f $ReleaseName) -ForegroundColor Yellow
  try {
    helm uninstall $ReleaseName -n $Namespace
    Write-Host ("Successfully removed {0}" -f $ReleaseName) -ForegroundColor Green
  } catch {
    Write-Host ("Failed to remove {0}: {1}" -f $ReleaseName, $_.Exception.Message) -ForegroundColor Red
    exit 1
  }
}

Write-Host "`nVerifying removal..." -ForegroundColor Cyan
try {
  $pods = kubectl get pods -n $Namespace --no-headers 2>$null
  if ($pods) {
    Write-Host "Remaining pods in namespace:" -ForegroundColor Yellow
    kubectl get pods -n $Namespace
  } else {
    Write-Host "No pods remaining in namespace" -ForegroundColor Green
  }
} catch {
  Write-Host "Namespace may not exist or is empty" -ForegroundColor Green
}

Write-Host "`nRemoval completed!" -ForegroundColor Green
