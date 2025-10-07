# UDP Chat Helm Chart

Helm chart for deploying the UDP Chat application on Kubernetes with support for testing and production (blue/green) environments.

## 🏗️ Architecture

The chart deploys a complete UDP Chat stack including:

- **NGINX** - Frontend (React SPA) + runtime config API
- **Connector** - WebSocket-to-UDP bridge (Node.js)
- **UDP Server** - Python backend with AI integration
- **PostgreSQL** - Database (testing only, production uses Azure PostgreSQL)
- **Prometheus** - Metrics collection (production only)
- **Grafana** - Monitoring dashboards (production only)

## 📦 Components

### Services

| Service      | Type      | Port(s)        | Description                  |
|--------------|-----------|----------------|------------------------------|
| `nginx`      | ClusterIP | 80             | Frontend + config API        |
| `connector`  | ClusterIP | 8000, 3000     | WebSocket bridge             |
| `udp`        | ClusterIP | 9999/UDP, 8080 | UDP server + metrics         |
| `postgres`   | ClusterIP | 5432           | PostgreSQL (testing only)    |
| `prometheus` | ClusterIP | 9090           | Metrics (production only)    |
| `grafana`    | ClusterIP | 3001           | Dashboards (production only) |

### Ingress Routes

**Testing Environment:**
- `testing.chat.kudriavcev.info` → NGINX frontend

**Production Environment (Blue/Green):**
- `blue.chat.kudriavcev.info` → Blue environment
- `green.chat.kudriavcev.info` → Green environment
- `www.chat.kudriavcev.info` → Active environment (configurable)
- `grafana.chat.kudriavcev.info` → Grafana dashboard
- `prometheus.chat.kudriavcev.info` → Prometheus UI

## 🚀 Installation

### Prerequisites

1. **Kubernetes cluster** (AKS, GKE, EKS, etc.)
2. **Helm 3.x** installed
3. **cert-manager** installed (for TLS certificates)
4. **Ingress controller** (nginx-ingress recommended)

### Create Secrets

Before deploying, create the application secret using the provided sample files:

```bash
# For testing
cp secret.testing.yaml.sample secret.testing.yaml
# Edit secret.testing.yaml with your actual values
kubectl apply -f secret.testing.yaml -n udpchat-testing

# For production
cp secret.yaml.sample secret.yaml
# Edit secret.yaml with your actual values
kubectl apply -f secret.yaml -n udpchat-prod
```

> **Note:** When using GitHub Actions, secrets are created automatically from repository secrets. See [GitHub Actions documentation](../../../.github/workflows/README.md) for details.

### Deploy Testing Environment

```bash
helm upgrade --install udpchat-testing . \
  --namespace udpchat-testing \
  --create-namespace \
  -f values.testing.yaml \
  --set deployTarget=testing \
  --set images.nginx=udpchatnewacr.azurecr.io/client:testing-latest \
  --set images.connector=udpchatnewacr.azurecr.io/connector:testing-latest \
  --set images.udp=udpchatnewacr.azurecr.io/server:testing-latest \
  --wait
```

### Deploy Production (Blue/Green)

**Deploy to Blue:**
```bash
helm upgrade --install udpchat-blue . \
  --namespace udpchat-prod \
  --create-namespace \
  -f values.prod.yaml \
  --set deployTarget=blue \
  --set images.nginx=udpchatnewacr.azurecr.io/client:latest \
  --set images.connector=udpchatnewacr.azurecr.io/connector:latest \
  --set images.udp=udpchatnewacr.azurecr.io/server:latest \
  --wait
```

**Deploy to Green:**
```bash
helm upgrade --install udpchat-green . \
  --namespace udpchat-prod \
  --create-namespace \
  -f values.prod.yaml \
  --set deployTarget=green \
  --set images.nginx=udpchatnewacr.azurecr.io/client:latest \
  --set images.connector=udpchatnewacr.azurecr.io/connector:latest \
  --set images.udp=udpchatnewacr.azurecr.io/server:latest \
  --wait
```

## ⚙️ Configuration

### Key Values

| Parameter          | Description                | Default                                     | Values File    |
|--------------------|----------------------------|---------------------------------------------|----------------|
| `domain`           | Base domain for ingress    | `chat.kudriavcev.info`                      | `values.yaml`  |
| `deployTarget`     | Deployment target          | `testing`                                   | Set per deploy |
| `activeColor`      | Active environment for www | `green`                                     | `values.yaml`  |
| `images.nginx`     | Frontend image             | `udpchatnewacr.azurecr.io/client:latest`    | All            |
| `images.connector` | Connector image            | `udpchatnewacr.azurecr.io/connector:latest` | All            |
| `images.udp`       | Server image               | `udpchatnewacr.azurecr.io/server:latest`    | All            |

### Environment-Specific Values

#### Testing (`values.testing.yaml`)
- **Replicas**: 1 per service (minimal footprint)
- **Database**: In-cluster PostgreSQL (ephemeral)
- **Monitoring**: Disabled
- **TLS**: Let's Encrypt via cert-manager
- **Subdomain**: `testing.{domain}`

#### Production (`values.prod.yaml`)
- **Replicas**: 2 per service (high availability)
- **Database**: Azure PostgreSQL (external)
- **Monitoring**: Enabled (Prometheus + Grafana)
- **TLS**: Let's Encrypt via cert-manager
- **Subdomains**: `blue.{domain}`, `green.{domain}`, `www.{domain}`

### Deployment Targets

| Target    | Description                  | Use Case              |
|-----------|------------------------------|-----------------------|
| `testing` | Single testing environment   | Development/staging   |
| `blue`    | Blue production environment  | Blue/green deployment |
| `green`   | Green production environment | Blue/green deployment |
| `both`    | Both blue and green          | Initial setup         |
| `www`     | WWW ingress only             | Traffic management    |

## 🔄 Blue/Green Deployment

The chart supports zero-downtime deployments using blue/green strategy:

### 1. Initial Setup

Deploy both environments:
```bash
# Deploy blue
helm upgrade --install udpchat-blue . \
  --namespace udpchat-prod \
  -f values.prod.yaml \
  --set deployTarget=blue

# Deploy green
helm upgrade --install udpchat-green . \
  --namespace udpchat-prod \
  -f values.prod.yaml \
  --set deployTarget=green
```

### 2. Update Inactive Environment

When deploying a new version, update the **inactive** environment:

```bash
# If green is active, update blue
helm upgrade udpchat-blue . \
  --namespace udpchat-prod \
  -f values.prod.yaml \
  --set deployTarget=blue \
  --set images.nginx=udpchatnewacr.azurecr.io/client:v2.0.0
```

### 3. Test Inactive Environment

Access via color-specific subdomain:
- `https://blue.chat.kudriavcev.info` (if blue is inactive)

### 4. Switch Traffic

Use the deployment scripts:
```bash
./deploy/scripts/set-active.sh blue
```

Or manually update the active color:
```bash
helm upgrade --install udpchat-www . \
  --namespace udpchat-prod \
  -f values.prod.yaml \
  --set deployTarget=www \
  --set activeColor=blue
```

## 🔐 Secrets Management

### Required Secret: `udpchat-app`

The chart expects a secret named `udpchat-app` (configurable via `existingAppSecret.name`) with these keys:

| Key | Description | Required For |
|-----|-------------|--------------|
| `DB_HOST` | PostgreSQL host | All |
| `DB_PORT` | PostgreSQL port | All |
| `DB_NAME` | Database name | All |
| `DB_USER` | Database user | All |
| `DB_PASSWORD` | Database password | All |
| `OPENAI_API_KEY` | OpenAI API key | AI features |
| `POSTGRES_PASSWORD` | PostgreSQL admin password | Testing only |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | Production only |

### Creating Secrets

**Method 1: Using Secret Files (Recommended for Manual Deployment)**

Use the provided sample files:

```bash
# Testing environment
cp secret.testing.yaml.sample secret.testing.yaml
# Edit secret.testing.yaml with your actual values
kubectl apply -f secret.testing.yaml -n udpchat-testing

# Production environment (includes Grafana password)
cp secret.yaml.sample secret.yaml
# Edit secret.yaml with your actual values
kubectl apply -f secret.yaml -n udpchat-prod
```

**Method 2: GitHub Actions (Recommended for CI/CD)**

Secrets are created automatically from GitHub repository secrets. No manual secret files needed.

See [GitHub Actions Workflows documentation](../../../.github/workflows/README.md) for required secrets.

## 📊 Monitoring

Production deployments include monitoring stack:

### Grafana
- **URL**: `https://grafana.{domain}`
- **Username**: `admin`
- **Password**: From `GRAFANA_ADMIN_PASSWORD` secret
- **Dashboards**: Pre-configured for UDP Chat metrics

### Prometheus
- **URL**: `https://prometheus.{domain}`
- **Metrics**: `/metrics` endpoints from all services
- **Retention**: Configurable (default: 15 days)

### Available Metrics
- HTTP request rates and latencies
- WebSocket connections
- UDP packet processing
- Database query performance
- Custom application metrics

## 🔧 Customization

### Resource Limits

Override in your values file:

```yaml
nginx:
  resources:
    requests:
      cpu: "100m"
      memory: "128Mi"
    limits:
      cpu: "500m"
      memory: "256Mi"

connector:
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1"
      memory: "512Mi"
```

### Scaling

```bash
# Scale replicas
helm upgrade udpchat-testing . \
  --reuse-values \
  --set nginx.replicas=3 \
  --set connector.replicas=3
```

### Domain Configuration

```bash
helm upgrade udpchat-testing . \
  --reuse-values \
  --set domain=myapp.example.com
```

## 🐛 Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n udpchat-testing
kubectl get pods -n udpchat-prod -l app.kubernetes.io/color=blue
```

### View Logs
```bash
# NGINX logs
kubectl logs -n udpchat-testing -l app=nginx -f

# Connector logs
kubectl logs -n udpchat-testing -l app=connector -f

# UDP server logs
kubectl logs -n udpchat-testing -l app=udp -f
```

### Check Ingress
```bash
kubectl get ingress -n udpchat-testing
kubectl describe ingress udpchat-testing -n udpchat-testing
```

### Debug Certificate Issues
```bash
# Check certificate
kubectl get certificate -n udpchat-testing

# Check cert-manager challenges
kubectl get challenges -n udpchat-testing

# Describe certificate for details
kubectl describe certificate udpchat-testing-tls -n udpchat-testing
```

## 📚 Files Reference

### Chart Files

```
chart/
├── Chart.yaml                          # Chart metadata
├── values.yaml                         # Default values
├── values.testing.yaml                 # Testing environment overrides
├── values.prod.yaml                    # Production environment overrides
├── secret.testing.yaml.sample          # Sample testing secret
├── secret.yaml.sample                  # Sample production secret
└── templates/
    ├── _helpers.tpl                    # Template helpers
    ├── certificate.yaml                # TLS certificate
    ├── configmap-*.yaml                # Configuration maps
    ├── deployment-*.yaml               # Deployments
    ├── ingress-*.yaml                  # Ingress routes
    ├── service-*.yaml                  # Services
    ├── stateful-postgres.yaml          # PostgreSQL StatefulSet
    └── secret-app.yaml                 # Application secret (if not using existing)
```

## 🔗 Related Documentation

- [Deployment Scripts](../../scripts/README.md)
- [GitHub Actions Workflows](../../../.github/workflows/README.md)
- [Terraform Infrastructure](../../terraform/README.md)

## 📝 Notes

- The chart is designed for single-region deployment
- PostgreSQL persistence is disabled by default in testing (use ephemeral storage)
- Production uses external Azure PostgreSQL for data persistence
- Blue/green deployments require manual traffic switching
- TLS certificates are automatically provisioned via cert-manager
