# UDP Chat - Docker Deployment

Quick guide for running the UDP Chat application with Docker Compose.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Ports 3000, 8000, 8001, 9090, 3001 available

## Setup

1. **Navigate to docker directory:**
   ```bash
   cd deploy/docker
   ```

2. **Create environment file:**
   ```bash
   cp env.sample .env
   # Edit .env if needed (optional)
   ```

## Production Deployment

**Start all services:**
```bash
docker-compose up -d
```

**Check status:**
```bash
docker-compose ps
```

**View logs:**
```bash
docker-compose logs -f
```

**Stop and remove:**
```bash
docker-compose down
```

**Access:**
- Web Client: http://localhost:3000
- WebSocket Connector: ws://localhost:8001
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001

## Common Commands

**Rebuild containers:**
```bash
docker-compose build --no-cache
```

**Restart specific service:**
```bash
docker-compose restart server
```

**Execute command in container:**
```bash
docker-compose exec server python main.py --help
```

**Remove everything (including volumes):**
```bash
docker-compose down -v --remove-orphans
```

## Troubleshooting

**Port conflicts:**
```bash
# Check what's using ports
netstat -tulpn | grep :3000
```

**Permission issues:**
```bash
sudo chown -R $USER:$USER .
```

**View container logs:**
```bash
docker-compose logs server
docker-compose logs postgresql
```

**Check container health:**
```bash
docker-compose ps
```

## Services

- **postgresql**: Database (port 5432)
- **server**: UDP server (port 9999)
- **connector**: WebSocket bridge (port 8001)
- **client**: React web app (port 3000)
- **prometheus**: Metrics (port 9090)
- **grafana**: Dashboards (port 3001)