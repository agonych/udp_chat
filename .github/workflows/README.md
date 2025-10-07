# GitHub Actions Workflows

This directory contains CI/CD workflows for automated testing, security scanning, and deployment of the UDP Chat application.

## 📋 Available Workflows

### 1. Testing CI (`testing-ci.yml`)

**Trigger:** Push to `testing` branch or manual trigger

**Purpose:** Automated testing, security scanning, and deployment to the testing environment.

#### Jobs:
1. **Unit Tests** - Run pytest with PostgreSQL, generate coverage reports
2. **Snyk Dependency Scan** - Scan Python dependencies for vulnerabilities
3. **Build Docker Images** - Build server, connector, and client images
4. **Docker Scout Scan** - Scan container images for CVEs (optional)
5. **Push to ACR** - Push images to Azure Container Registry with tags: `{SHA}` and `testing-latest`
6. **Deploy to Testing** - Deploy to `udpchat-testing` namespace in AKS

#### Image Tags:
- `udpchatnewacr.azurecr.io/server:{SHA}`
- `udpchatnewacr.azurecr.io/server:testing-latest`
- Same for connector and client

#### Namespace: `udpchat-testing`

---

### 2. Production CI (`production-ci.yml`)

**Trigger:** Push to `production` branch or manual trigger

**Purpose:** Build and deploy to production using blue/green deployment strategy.

#### Jobs:
1. **Build Docker Images** - Build server, connector, and client images
2. **Push to ACR** - Push images to Azure Container Registry with tags: `{SHA}` and `latest`
3. **Deploy to Inactive Color** - Automatically deploy to the inactive environment (blue/green)

#### Blue/Green Deployment:
- Automatically detects the current **active** color (blue or green)
- Deploys to the **inactive** color
- Allows testing before switching traffic
- Use `./deploy/scripts/set-active.sh {color}` to switch traffic

#### Image Tags:
- `udpchatnewacr.azurecr.io/server:{SHA}`
- `udpchatnewacr.azurecr.io/server:latest`
- Same for connector and client

#### Namespace: `udpchat-prod`

---

## 🔑 Required Secrets

Add these secrets in your GitHub repository: **Settings** → **Secrets and variables** → **Actions**

### Azure OIDC Authentication (Required for both workflows)

| Secret                  | Description                      | Example                                |
|-------------------------|----------------------------------|----------------------------------------|
| `AZURE_CLIENT_ID`       | Azure AD Application (Client) ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID`       | Azure AD Tenant ID               | `87654321-4321-4321-4321-210987654321` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID            | `abcdef12-3456-7890-abcd-ef1234567890` |

### Security Scanning (Required for testing workflow)

| Secret       | Description                            | Where to Get                                              |
|--------------|----------------------------------------|-----------------------------------------------------------|
| `SNYK_TOKEN` | Snyk API token for dependency scanning | [snyk.io](https://snyk.io) → Account Settings → API Token |

### Docker Hub (Optional - for Docker Scout)

| Secret            | Description             | Where to Get                                                |
|-------------------|-------------------------|-------------------------------------------------------------|
| `DOCKER_USERNAME` | Docker Hub username     | Your Docker Hub account                                     |
| `DOCKER_PASSWORD` | Docker Hub access token | Docker Hub → Account Settings → Security → New Access Token |

> **Note:** Docker Scout scanning will be skipped if these credentials are not provided. Snyk scanning provides adequate
> security coverage.

### Application Secrets (Required for deployment)

| Secret                      | Description                        | Used In                |
|-----------------------------|------------------------------------|------------------------|
| `OPENAI_API_KEY`            | OpenAI API key for AI features     | Both environments      |
| `POSTGRES_PASSWORD_TESTING` | PostgreSQL password for testing    | Testing environment    |
| `POSTGRES_PASSWORD`         | PostgreSQL password for production | Production environment |
| `GRAFANA_ADMIN_PASSWORD`    | Grafana dashboard admin password   | Production only        |

---

## 🚀 Quick Start

### Testing Environment

1. **Add required secrets** to your GitHub repository
2. **Push to `testing` branch**:
   ```bash
   git checkout testing
   git merge main
   git push origin testing
   ```
3. **Monitor the workflow** in the Actions tab
4. **Access your testing environment** once deployed

### Production Environment

1. **Ensure all secrets are configured**
2. **Push to `production` branch**:
   ```bash
   git checkout production
   git merge main
   git push origin production
   ```
3. **Workflow deploys to inactive color** (e.g., blue if green is active)
4. **Test the inactive environment**
5. **Switch traffic** when ready:
   ```bash
   ./deploy/scripts/set-active.sh blue
   ```
