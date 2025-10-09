# Deployment Scripts

This directory contains deployment scripts for both Windows (PowerShell) and Linux (Bash) environments.

## Available Scripts

### 1. Infrastructure Up Script (`infra-up.ps1` / `infra-up.sh`)
Deploys the infrastructure using Terraform in two phases.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\infra-up.ps1
```

**Linux (Bash):**
```bash
./deploy/scripts/infra-up.sh
```

This runs:
- Phase 1: `terraform apply` (Azure infra only: AKS/ACR/Postgres/Static IP)
- Phase 2: `terraform apply -var enable_k8s=true` (Kubernetes + Helm + DNS)
- Phase 3: `terraform apply -var enable_k8s=true -var enable_clusterissuer=true` (ClusterIssuer)

### 2. Infrastructure Down Script (`infra-down.ps1` / `infra-down.sh`)
Destroys the infrastructure using Terraform in two phases (reverse order).

**Windows (PowerShell):**
```powershell
.\deploy\scripts\infra-down.ps1
```

**Linux (Bash):**
```bash
./deploy/scripts/infra-down.sh
```

This runs:
- Phase 1: `terraform destroy -var enable_k8s=true -var enable_clusterissuer=true` (Kubernetes + Helm + DNS + Issuer)
- Phase 2: `terraform destroy -var enable_k8s=false` (Azure infra)

### 3. Build and Push Script (`build-and-push.ps1` / `build-and-push.sh`)
Builds and pushes Docker images to Azure Container Registry.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\build-and-push.ps1 [-Tag <tag>] [-Service <service>] [-Help]
```

**Linux (Bash):**
```bash
./deploy/scripts/build-and-push.sh [-t|--tag <tag>] [-s|--service <service>] [-h]
```

**Options:**
- `-Tag <tag>` / `-t <tag>` - Docker image tag (default: latest)
- `-Service <service>` / `-s <service>` - Service to build (default: all)
- `-Help` / `-h` - Show help message

**Services:**
- `server` - UDP chat server
- `connector` - WebSocket connector  
- `client` - Frontend application
- `all` - All services (default)

**Examples:**
```bash
# Build all services with latest tag
./build-and-push.sh

# Build only server with v1.2.3 tag
./build-and-push.sh -t v1.2.3 -s server

# Build only client and connector
./build-and-push.sh -s client
./build-and-push.sh -s connector
```

Notes:
- The previous `setup-ingress` and `get-ssl` scripts are no longer required; ingress-nginx and cert-manager are provisioned by Terraform.
- AKS Standard LB is pre-configured (externalTrafficPolicy=Local). No manual NSG steps needed.
- Deploy scripts auto-apply environment secrets if present: `secret.testing.yaml` for testing, `secret.yaml` for prod.

### 4. AKS Login Script (`aks-login.ps1` / `aks-login.sh`) ⭐ NEW
Authenticates kubectl to the AKS cluster using credentials from Terraform outputs.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\aks-login.ps1
```

**Linux (Bash):**
```bash
./deploy/scripts/aks-login.sh
```

**What it does:**
- Reads AKS cluster name and resource group from Terraform outputs
- Runs `az aks get-credentials` to configure kubectl
- Tests the connection to verify authentication
- Shows cluster nodes and current context

**Prerequisites:**
- Run `az login` first
- Infrastructure must be deployed (`infra-up.ps1`)

**When to use:**
- First time after running `infra-up.ps1`
- After switching Azure subscriptions
- If kubectl connection is lost
- Fresh terminal session

**Note:** You only need to run this once per session. Kubectl credentials persist.

### 5. Deploy Script (`deploy.ps1` / `deploy.sh`)
Deploys the UDP Chat application to different environments.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\deploy.ps1 -Environment testing [-Tag <tag>] [-Wait] [-Help]
.\deploy\scripts\deploy.ps1 -Environment blue|green|both|active|inactive [-Tag <tag>] [-Wait] [-Help]
```

**Linux (Bash):**
```bash
./deploy/scripts/deploy.sh -e testing [-t <tag>] [-w] [-h]
./deploy/scripts/deploy.sh -e blue|green|both|active|inactive [-t <tag>] [-w] [-h]
```

**Environments:**
- `testing` - Deploys to `udpchat-testing` namespace using `values.testing.yaml`
- `blue` - Deploys blue environment to `udpchat-prod` namespace
- `green` - Deploys green environment to `udpchat-prod` namespace  
- `both` - Deploys both blue and green environments
- `active` - Deploys to currently active color (green)
- `inactive` - Deploys to currently inactive color (blue)

**Options:**
- `-Environment <env>` / `-e <env>` - Environment to deploy
- `-Tag <tag>` / `-t <tag>` - Docker image tag to deploy (default: latest)
- `-Wait` / `-w` - Wait for deployment to complete
- `-Help` / `-h` - Show help message

### 6. Remove Script (`remove.ps1` / `remove.sh`)
Removes deployments from different environments.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\remove.ps1 -Environment testing [-Help]
.\deploy\scripts\remove.ps1 -Environment blue|green|both|www|active|inactive [-Help]
```

**Linux (Bash):**
```bash
./deploy/scripts/remove.sh -e testing [-h]
./deploy/scripts/remove.sh -e blue|green|both|www|active|inactive [-h]
```

**Environments:**
- `testing` - Removes testing environment
- `blue`/`green`/`www` - Removes specific environment
- `both` - Removes both blue and green environments
- `active` - Removes currently active environment (green) - **with confirmation**
- `inactive` - Removes currently inactive environment (blue) - **safe**

**Options:**
- `-Environment <env>` / `-e <env>` - Environment to remove
- `-Help` / `-h` - Show help message

Behavior details:
- For prod, `active`/`inactive` are resolved dynamically from the `udpchat-www-active` ConfigMap; `active` removal prompts for confirmation.

### 7. Set Active (`set-active.ps1` / `set-active.sh`)
Switches the active colour for `www` (blue|green|toggle).

**Windows (PowerShell):**
```powershell
.\deploy\scripts\set-active.ps1 -Environment blue|green|toggle [-Wait]
```

**Linux (Bash):**
```bash
./deploy/scripts/set-active.sh blue|green|toggle [-w]
```

Notes:
- Detects current active from the `udpchat-www-active` ConfigMap; `toggle` flips it.
- Applies `deployTarget=www` and sets `activeColor` accordingly.
- Updates both the ConfigMap and ingress routing to the selected color.

### 8. Get Active (`get-active.ps1` / `get-active.sh`)
Prints the current active colour (blue|green) by reading the `udpchat-www-active` ConfigMap.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\get-active.ps1
```

**Linux (Bash):**
```bash
./deploy/scripts/get-active.sh
```

## Prerequisites

### Windows
- PowerShell 5.1 or later
- Azure CLI
- Docker Desktop
- Helm 3.x
- kubectl
- Terraform

### Linux
- Bash 4.0 or later
- Azure CLI
- Docker
- Helm 3.x
- kubectl
- Terraform

## Blue/Green Deployment

The application supports blue/green deployment strategy:

- **Blue Environment**: `blue.chat.kudriavcev.info`
- **Green Environment**: `green.chat.kudriavcev.info`
- **Production**: `www.chat.kudriavcev.info` (routes to the active colour)

**Check current active colour:**
- Windows: `./deploy/scripts/get-active.ps1`
- Linux: `./deploy/scripts/get-active.sh`

**Switching colours (no direct Helm needed):**
- Windows: `./deploy/scripts/set-active.ps1 -Environment blue|green|toggle [-Wait]`
- Linux: `./deploy/scripts/set-active.sh blue|green|toggle [-w]`

Notes:
- The scripts update the `www` ingress to point to the selected colour by setting `activeColor` for the `www` deploy target.

## Safety Features

- **Active environment removal** requires confirmation
- **Inactive environment removal** is safe (no production impact)
- **Both environments removal** removes all production deployments
- **Testing environment** is isolated and safe to remove

## Complete Deployment Workflow

### 1. Infrastructure Setup
```bash
# Linux
./infra-up.sh

# Windows
.\infra-up.ps1
```

### 2. Authenticate to AKS Cluster
```bash
# Linux
./aks-login.sh

# Windows
.\aks-login.ps1
```

**Note:** Run this once after infrastructure setup, or when kubectl connection is lost.

### 3. Application Deployment (testing uses HTTPS by default)
```bash
# Linux
./build-and-push.sh
./deploy.sh -e testing -w
./deploy.sh -e inactive -t v1.2.3 -w

# Windows
.\build-and-push.ps1
.\deploy.ps1 -Environment testing -Wait
.\deploy.ps1 -Environment inactive -Tag v1.2.3 -Wait
```

### 4. Environment Management
```bash
# Linux
./deploy.sh -e active -t v1.2.3 -w    # Deploy to currently active colour
./remove.sh -e inactive                # Remove inactive environment
./set-active.sh toggle -w              # Flip www to the other colour

# Windows
.\deploy.ps1 -Environment active -Tag v1.2.3 -Wait
.\remove.ps1 -Environment inactive
```

### 5. Cleanup
```bash
# Linux
./remove.sh -e both
./infra-down.sh

# Windows
.\remove.ps1 -Environment both
.\infra-down.ps1
```

## Examples

```bash
# Complete setup from scratch (Windows)
.\infra-up.ps1
.\aks-login.ps1           # Authenticate kubectl
.\build-and-push.ps1
.\deploy.ps1 -Environment testing -Wait

# Complete setup from scratch (Linux)
./infra-up.sh
./aks-login.sh            # Authenticate kubectl
./build-and-push.sh
./deploy.sh -e testing -w

# Deploy new version to inactive environment
./build-and-push.sh
./deploy.sh -e inactive -t v1.2.3 -w

# Quick development workflow - only rebuild server
./build-and-push.sh -s server
./deploy.sh -e testing -w

# Switch to new version in production
./deploy.sh -e active -t v1.2.3 -w

# Clean up inactive environment
./remove.sh -e inactive

# Remove all environments
./remove.sh -e both

# Destroy infrastructure
./infra-down.sh
```