# UDP Chat - Local Kubernetes Deployment

This directory contains Kubernetes manifests for deploying the UDP Chat application to local Kubernetes (Docker Desktop).

## Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl installed and configured
- Docker images built locally (see Build Images section)

## Quick Start

### 1. Enable Kubernetes in Docker Desktop

1. Open Docker Desktop
2. Go to Settings → Kubernetes
3. Enable Kubernetes
4. Wait for Kubernetes to start

### 2. Configure Secrets

```bash
# Copy and edit the secret file
cp secret.yaml.sample secret.yaml
```

### 3. Build Docker Images

```bash
# Build all images
docker build -t server:latest ../../server
docker build -t connector:latest ../../connector
# Enure to supply correct WebSocket settings for frontend (or edit its .env file first)
docker build -t client:latest ../../client --build-arg VITE_WS_HOST=localhost --build-arg VITE_WS_PORT=30003 --build-arg VITE_WS_PATH=/ws
```

### 4. Deploy the Application

```bash
# Apply all manifests
kubectl apply -k .
```

### 5. Access the Application

The application will be available at:
- **Web Client**: http://localhost:30000
- **Prometheus**: http://localhost:30005
- **Grafana**: http://localhost:30006

No port-forwarding needed! All services use NodePort for direct access.

### 6. Remove the Application

```bash
kubectl delete namespace udpchat
```

## Check Status and Logs

```bash
# Check status
kubectl get pods -n udpchat
kubectl get services -n udpchat

# View logs
kubectl logs -f deployment/server -n udpchat
kubectl logs -f deployment/connector -n udpchat
kubectl logs -f deployment/client -n udpchat
kubectl logs -f deployment/prometheus -n udpchat
kubectl logs -f deployment/grafana -n udpchat
```

## Configuration

### Environment Variables

The application configuration is managed through:

- **ConfigMap** (`configmap.yaml`): Non-sensitive configuration
- **Secret** (`secret.yaml`): Sensitive data like passwords and API keys

**Note**: Before deploying, copy `secret.yaml.sample` to `secret.yaml` and update the values for your environment.

### WebSocket Configuration

The client is configured to connect to the WebSocket connector via:
- Host: `localhost`
- Port: `30003` (NodePort)
- Path: `/ws`

This is configured in the client deployment environment variables.

## Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───>│   Ingress    │───>│  Connector  │───>│   Server    │───>│ PostgreSQL  │   
│   (React)   │    │   (nginx)    │    │ (WebSocket) │    │    (UDP)    │    │ (Database)  │
└─────────────┘    └──────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                              │                 |
                                              v                 |
┌─────────────┐    ┌──────────────┐    ┌─────────────┐          |
│   Grafana   │<───│  Prometheus  │<───│   Metrics   │<─────────┘
│ (Dashboard) │    │ (Collector)  │    │ (Endpoints) │
└─────────────┘    └──────────────┘    └─────────────┘
```

## Useful Commands

```bash
   # Get all resources
   kubectl get all -n udpchat

   # Check pod status
   kubectl describe pods -n udpchat
   
   # Check logs
   kubectl logs -f deployment/server -n udpchat 
   kubectl logs -f deployment/connector -n udpchat
   kubectl logs -f deployment/server -n udpchat
   kubectl logs -f statefulset/postgresql -n udpchat
   
   # Execute commands in pods
   kubectl exec -it deployment/server -n udpchat -- /bin/sh
   kubectl exec -it statefulset/postgresql -n udpchat -- psql -U udpchat_user -d udpchat
   
   # Scale deployments
   kubectl scale deployment server --replicas=2 -n udpchat
   
   # View resource usage
   kubectl top pods -n udpchat
```

