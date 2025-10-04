#!/usr/bin/env pwsh
$ErrorActionPreference = 'Stop'

# Boots TLS for the cluster (cert-manager + ClusterIssuer + per-namespace Certificates).
# Uses templates in deploy/tls/ and a simple .env file for vars.

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Resolve-Path (Join-Path $ScriptDir '..\..')
$TlsDir    = Join-Path $RepoRoot 'deploy\tls'

# Files
$EnvFile   = Join-Path $TlsDir '.env'
$NsFile    = Join-Path $TlsDir '00-namespaces.yaml'
$TplIssuer = Join-Path $TlsDir '20-clusterissuer-letsencrypt-prod.tmpl.yaml'
$TplCertT  = Join-Path $TlsDir '30-certificate-testing.tmpl.yaml'
$TplCertP  = Join-Path $TlsDir '30-certificate-prod.tmpl.yaml'

Write-Host 'Checking config...'

# Load .env (KEY=VALUE; ignores blank lines and # comments), robust for CRLF/LF
$vars = @{}
$raw = Get-Content -Path $EnvFile -Raw -Encoding UTF8
$raw -split "(`r`n|`n|`r)" | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { return }
    $k = $line.Substring(0, $eq).Trim()
    $v = $line.Substring($eq + 1).Trim()
    if ( ($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'")) ) {
        $v = $v.Substring(1, $v.Length - 2)
    }
    $vars[$k] = $v
}

# Tiny ${VAR} renderer (envsubst-lite)
function Render-Template {
    param([string]$TemplatePath)
    $content = Get-Content -Raw $TemplatePath -Encoding UTF8
    $map = $vars
    return [regex]::Replace($content, '\$\{([A-Z0-9_]+)\}', {
        param($m)
        $name = $m.Groups[1].Value
        if ($map.ContainsKey($name)) { $map[$name] } else { $m.Value }
    })
}

# Optional: Azure login + get AKS kubeconfig
Write-Host 'Ensuring Azure login and AKS kubeconfig...'
try { az account show | Out-Null } catch { }
if (-not (az account show 2>$null)) {
    if ($vars.ContainsKey('APP_ID') -and $vars.ContainsKey('TENANT_ID') -and $vars.ContainsKey('CLIENT_SECRET') `
      -and $vars['APP_ID'] -and $vars['TENANT_ID'] -and $vars['CLIENT_SECRET']) {
        Write-Host 'Logging into Azure as service principal...'
        az login --service-principal `
          -u $vars['APP_ID'] `
          -p $vars['CLIENT_SECRET'] `
          --tenant $vars['TENANT_ID'] | Out-Null
    } else {
        Write-Host 'Logging into Azure with device code...'
        az login --use-device-code | Out-Null
    }
}
if ($vars.ContainsKey('SUBSCRIPTION_ID') -and $vars['SUBSCRIPTION_ID']) {
    az account set --subscription $vars['SUBSCRIPTION_ID'] | Out-Null
}
if ($vars.ContainsKey('AKS_NAME') -and $vars['AKS_NAME']) {
    Write-Host ("Fetching AKS kubeconfig for RG '{0}', AKS '{1}'..." -f $vars['RESOURCE_GROUP'], $vars['AKS_NAME'])
    az aks get-credentials -g $vars['RESOURCE_GROUP'] -n $vars['AKS_NAME'] --overwrite-existing | Out-Null
}

# Create namespaces
Write-Host 'Creating namespaces (no dramas if they already exist)...'
kubectl apply --validate=false -f $NsFile | Out-Null

# Install cert-manager (CRDs via kubectl, chart via Helm WITHOUT CRDs)
Write-Host 'Installing cert-manager (one-off)...'
kubectl apply --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.crds.yaml | Out-Null

@"
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
"@ | kubectl apply --validate=false -f - | Out-Null

helm repo add jetstack https://charts.jetstack.io | Out-Null
helm repo update | Out-Null
helm upgrade --install cert-manager jetstack/cert-manager `
  -n cert-manager `
  --skip-crds `
  --set installCRDs=false `
  | Out-Null

# Wait for cert-manager to be ready
Write-Host 'Waiting for cert-manager to be ready...'
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=300s | Out-Null
kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=300s | Out-Null
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=300s | Out-Null

# Azure DNS creds secret (idempotent apply)
Write-Host 'Setting up Azure DNS creds for cert-manager...'
$clientSecret = $vars['CLIENT_SECRET']
$secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: le-azure-dns
  namespace: cert-manager
type: Opaque
stringData:
  client-secret: "$clientSecret"
"@
$secretYaml | kubectl apply --validate=false -f - | Out-Null

# Apply ClusterIssuer
Write-Host 'Applying ClusterIssuer...'
$issuerYaml = Render-Template -TemplatePath $TplIssuer
$issuerOut  = Join-Path $TlsDir '20-clusterissuer-letsencrypt-prod.yaml'
Set-Content -Path $issuerOut -Value $issuerYaml -Encoding UTF8 -NoNewline
kubectl apply --validate=false -f $issuerOut | Out-Null

# Apply wildcard Certificates in both namespaces
Write-Host 'Requesting wildcard certs in both namespaces...'
$certTYaml = Render-Template -TemplatePath $TplCertT
$certPYaml = Render-Template -TemplatePath $TplCertP
$certTOut  = Join-Path $TlsDir '30-certificate-testing.yaml'
$certPOut  = Join-Path $TlsDir '30-certificate-prod.yaml'
Set-Content -Path $certTOut -Value $certTYaml -Encoding UTF8 -NoNewline
Set-Content -Path $certPOut -Value $certPYaml -Encoding UTF8 -NoNewline

$nsTesting = $vars['NS_TESTING']
$nsProd    = $vars['NS_PROD']

kubectl -n $nsTesting apply --validate=false -f $certTOut | Out-Null
kubectl -n $nsProd    apply --validate=false -f $certPOut | Out-Null

# Wait for Certificates to be Ready, then verify the TLS secrets exist
$nsList = @($nsTesting, $nsProd)

Write-Host 'Waiting for certificates to be Ready...'
foreach ($ns in $nsList) {
    Write-Host ("  {0}: waiting for certificate/wildcard-udpchat" -f $ns)
    $res = kubectl -n $ns wait --for=condition=Ready certificate/wildcard-udpchat --timeout=600s 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host $res
        throw ("Certificate did not become Ready in namespace {0}" -f $ns)
    }
}

Write-Host 'Verifying TLS secrets exist...'
foreach ($ns in $nsList) {
    $name = (kubectl -n $ns get secret wildcard-udpchat-tls -o name --ignore-not-found)
    if (-not $name) {
        throw ("TLS secret wildcard-udpchat-tls missing in namespace {0}" -f $ns)
    }
    Write-Host ("  {0}: found {1}" -f $ns, $name)
}

Write-Host "OK: TLS is saved to secret 'wildcard-udpchat-tls' in each namespace."
