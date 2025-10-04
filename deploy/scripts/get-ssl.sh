#!/usr/bin/env bash
set -euo pipefail

# Boots TLS for the cluster (cert-manager + ClusterIssuer + per-namespace Certificates).
# Uses templates in deploy/tls/ and a simple .env file for vars.
# Prereqs: kubectl, helm, envsubst (from gettext), az (optional but recommended).

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TLS_DIR="${REPO_ROOT}/deploy/tls"

# Files
ENV_FILE="${TLS_DIR}/.env"
NS_FILE="${TLS_DIR}/00-namespaces.yaml"
TPL_ISSUER="${TLS_DIR}/20-clusterissuer-letsencrypt-prod.tmpl.yaml"
TPL_CERT_T="${TLS_DIR}/30-certificate-testing.tmpl.yaml"
TPL_CERT_P="${TLS_DIR}/30-certificate-prod.tmpl.yaml"

echo "Checking config..."
# shellcheck disable=SC1090
set -a
. "${ENV_FILE}"
set +a

# Optional Azure login + AKS kubeconfig
echo "Ensuring Azure login and AKS kubeconfig..."
if command -v az >/dev/null 2>&1; then
  if ! az account show >/dev/null 2>&1; then
    if [[ -n "${APP_ID:-}" && -n "${TENANT_ID:-}" && -n "${CLIENT_SECRET:-}" ]]; then
      echo "Logging into Azure as service principal..."
      az login --service-principal -u "${APP_ID}" -p "${CLIENT_SECRET}" --tenant "${TENANT_ID}" >/dev/null
    else
      echo "Logging into Azure with device code..."
      az login --use-device-code >/dev/null
    fi
  fi
  if [[ -n "${SUBSCRIPTION_ID:-}" ]]; then
    az account set --subscription "${SUBSCRIPTION_ID}" >/dev/null
  fi
  if [[ -n "${AKS_NAME:-}" && -n "${RESOURCE_GROUP:-}" ]]; then
    echo "Fetching AKS kubeconfig for RG '${RESOURCE_GROUP}', AKS '${AKS_NAME}'..."
    az aks get-credentials -g "${RESOURCE_GROUP}" -n "${AKS_NAME}" --overwrite-existing >/dev/null
  fi
else
  echo "Warning: Azure CLI (az) not found; skipping az login and AKS credentials fetch."
fi

# Namespaces
echo "Creating namespaces (no dramas if they already exist)..."
kubectl apply --validate=false -f "${NS_FILE}" >/dev/null

# Install cert-manager: CRDs via kubectl; Helm without CRDs (avoid ownership conflicts)
echo "Installing cert-manager (one-off)..."
kubectl apply --validate=false -f "https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.crds.yaml" >/dev/null

cat <<'YAML' | kubectl apply --validate=false -f - >/dev/null
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
YAML

helm repo add jetstack https://charts.jetstack.io >/dev/null
helm repo update >/dev/null
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager \
  --skip-crds \
  --set installCRDs=false \
  >/dev/null

echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=300s >/dev/null
kubectl wait --for=condition=Available deployment/cert-manager-cainjector -n cert-manager --timeout=300s >/dev/null
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=300s >/dev/null

# Azure DNS creds secret (idempotent apply)
echo "Setting up Azure DNS creds for cert-manager..."
: "${CLIENT_SECRET:?CLIENT_SECRET must be set in .env}"
cat <<YAML | kubectl apply --validate=false -f - >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: le-azure-dns
  namespace: cert-manager
type: Opaque
stringData:
  client-secret: "${CLIENT_SECRET}"
YAML

# Apply ClusterIssuer (render from template)
echo "Applying ClusterIssuer..."
ISSUER_OUT="${TLS_DIR}/20-clusterissuer-letsencrypt-prod.yaml"
envsubst < "${TPL_ISSUER}" > "${ISSUER_OUT}"
kubectl apply --validate=false -f "${ISSUER_OUT}" >/dev/null

# Apply wildcard Certificates in both namespaces
echo "Requesting wildcard certs in both namespaces..."
CERT_T_OUT="${TLS_DIR}/30-certificate-testing.yaml"
CERT_P_OUT="${TLS_DIR}/30-certificate-prod.yaml"
envsubst < "${TPL_CERT_T}" > "${CERT_T_OUT}"
envsubst < "${TPL_CERT_P}" > "${CERT_P_OUT}"

: "${NS_TESTING:?NS_TESTING must be set in .env}"
: "${NS_PROD:?NS_PROD must be set in .env}"

kubectl -n "${NS_TESTING}" apply --validate=false -f "${CERT_T_OUT}" >/dev/null
kubectl -n "${NS_PROD}"    apply --validate=false -f "${CERT_P_OUT}" >/dev/null

# Wait for Certificates to be Ready, then verify TLS secrets exist
echo "Waiting for certificates to be Ready..."
for ns in "${NS_TESTING}" "${NS_PROD}"; do
  echo "  ${ns}: waiting for certificate/wildcard-udpchat"
  if ! kubectl -n "${ns}" wait --for=condition=Ready certificate/wildcard-udpchat --timeout=600s; then
    echo "Certificate did not become Ready in namespace ${ns}"
    exit 1
  fi
done

echo "Verifying TLS secrets exist..."
for ns in "${NS_TESTING}" "${NS_PROD}"; do
  if ! kubectl -n "${ns}" get secret wildcard-udpchat-tls -o name --ignore-not-found | grep -q .; then
    echo "TLS secret wildcard-udpchat-tls missing in namespace ${ns}"
    exit 1
  fi
  echo "  ${ns}: found secret/wildcard-udpchat-tls"
done

echo "OK: TLS is saved to secret 'wildcard-udpchat-tls' in each namespace."
