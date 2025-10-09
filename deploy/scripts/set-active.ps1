#!/usr/bin/env pwsh
param(
  [ValidateSet('blue','green','toggle')]
  [string]$Environment,
  [switch]$Wait,
  [switch]$Help
)

if ($Help -or -not $Environment) {
  Write-Host @"
Set active colour for www (blue|green|toggle)

Usage:
  .\deploy\scripts\set-active.ps1 -Environment blue|green|toggle [-Wait]
"@
  exit 0
}

$ErrorActionPreference = 'Stop'

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir '..\..')
$ChartDir  = Resolve-Path (Join-Path $RepoRoot 'deploy\helm\chart')
$Ns = 'udpchat-prod'
$Release = 'udpchat-www'

# Detect current active colour from configmap-active
$current = ''
try {
  $current = kubectl -n $Ns get configmap ${Release}-active -o jsonpath='{.data.active}' 2>$null
  if ($current) { $current = $current.Trim() }
} catch {}

if (-not $current) { $current = 'green' }

switch ($Environment) {
  'toggle' { $new = if ($current -eq 'green') { 'blue' } else { 'green' } }
  default  { $new = $Environment }
}

Write-Host ("Current: {0} -> New: {1}" -f $current, $new)

# Build helm args
$args = @('upgrade','--install',$Release,$ChartDir,
          '--namespace',$Ns,
          '-f', (Join-Path $ChartDir 'values.prod.yaml'),
          '--set','deployTarget=www',
          '--set',"activeColor=$new")
if ($Wait) { $args += @('--wait','--timeout','10m') }

helm repo update | Out-Null
& helm @args

Write-Host ("www now routes to: {0}" -f $new)

