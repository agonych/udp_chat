# Deployment Scripts

This directory contains deployment scripts for both Windows (PowerShell) and Linux (Bash) environments.

## Available Scripts

### 1. Infrastructure Up Script (`infra-up.ps1` / `infra-up.sh`)
Deploys the infrastructure using Terraform.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\infra-up.ps1 [-TerraformDir <path>] [-Help]
```

**Linux (Bash):**
```bash
./deploy/scripts/infra-up.sh [-d <path>] [-h]
```

**Options:**
- `-TerraformDir <path>` / `-d <path>` - Terraform directory path
- `-Help` / `-h` - Show help message

### 2. Infrastructure Down Script (`infra-down.ps1` / `infra-down.sh`)
Destroys the infrastructure using Terraform.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\infra-down.ps1 [-TerraformDir <path>] [-Help]
```

**Linux (Bash):**
```bash
./deploy/scripts/infra-down.sh [-d <path>] [-h]
```

**Options:**
- `-TerraformDir <path>` / `-d <path>` - Terraform directory path
- `-Help` / `-h` - Show help message

### 3. Build and Push Script (`build-and-push.ps1` / `build-and-push.sh`)
Builds and pushes Docker images to Azure Container Registry.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\build-and-push.ps1 [-Help]
```

**Linux (Bash):**
```bash
./deploy/scripts/build-and-push.sh [-h]
```

**Options:**
- `-Help` / `-h` - Show help message

**Images built:**
- `server` - UDP chat server
- `connector` - WebSocket connector
- `client` - Frontend application

### 4. Setup Ingress Script (`setup-ingress.ps1` / `setup-ingress.sh`)
Sets up the ingress-nginx controller with static IP binding.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\setup-ingress.ps1 [-Namespace <ns>] [-Release <name>] [-TerraformDir <path>] [-NodeResourceGroup <rg>] [-DryRun] [-Help]
```

**Linux (Bash):**
```bash
./deploy/scripts/setup-ingress.sh [-n <ns>] [-r <name>] [-d <path>] [-g <rg>] [--dry-run] [-h]
```

**Options:**
- `-Namespace <ns>` / `-n <ns>` - Kubernetes namespace (default: ingress-nginx)
- `-Release <name>` / `-r <name>` - Helm release name (default: ingress-nginx)
- `-TerraformDir <path>` / `-d <path>` - Terraform directory path
- `-NodeResourceGroup <rg>` / `-g <rg>` - AKS node resource group
- `-DryRun` / `--dry-run` - Show commands without executing
- `-Help` / `-h` - Show help message

**Features:**
- Discovers Terraform outputs (IP, resource groups)
- Sets up kubeconfig for AKS
- Installs ingress-nginx with static IP binding
- Configures load balancer backend pool
- Sets up NSG rules for HTTP/HTTPS traffic

### 5. Get SSL Script (`get-ssl.ps1` / `get-ssl.sh`)
Obtains SSL certificates using cert-manager and Let's Encrypt.

**Windows (PowerShell):**
```powershell
.\deploy\scripts\get-ssl.ps1 [-Help]
```

**Linux (Bash):**
```bash
./deploy/scripts/get-ssl.sh [-h]
```

**Options:**
- `-Help` / `-h` - Show help message

### 6. Deploy Script (`deploy.ps1` / `deploy.sh`)
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

### 7. Remove Script (`remove.ps1` / `remove.sh`)
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

- **Blue Environment**: `blue.chat.kudriavcev.com`
- **Green Environment**: `green.chat.kudriavcev.com`
- **Production**: `www.chat.kudriavcev.com` (routes to active color)

**Current Active Color**: Green (configured in `values.yaml`)

**Switching Colors:**
1. Update `activeColor` in `values.yaml`
2. Redeploy www ingress: `helm upgrade --install udpchat-www deploy/helm/chart -n udpchat-prod -f deploy/helm/chart/values.prod.yaml --set deployTarget=www --wait`

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
./setup-ingress.sh
./get-ssl.sh

# Windows
.\infra-up.ps1
.\setup-ingress.ps1
.\get-ssl.ps1
```

### 2. Application Deployment
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

### 3. Environment Management
```bash
# Linux
./deploy.sh -e active -t v1.2.3 -w  # Deploy to active environment
./remove.sh -e inactive              # Remove inactive environment

# Windows
.\deploy.ps1 -Environment active -Tag v1.2.3 -Wait
.\remove.ps1 -Environment inactive
```

### 4. Cleanup
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
# Complete setup from scratch
./infra-up.sh
./setup-ingress.sh
./get-ssl.sh
./build-and-push.sh
./deploy.sh -e testing -w

# Deploy new version to inactive environment
./build-and-push.sh
./deploy.sh -e inactive -t v1.2.3 -w

# Switch to new version in production
./deploy.sh -e active -t v1.2.3 -w

# Clean up inactive environment
./remove.sh -e inactive

# Remove all environments
./remove.sh -e both

# Destroy infrastructure
./infra-down.sh
```