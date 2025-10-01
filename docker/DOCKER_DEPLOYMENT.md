# Docker Deployment Guide

This guide explains how to deploy the UDPChat-AI application using Docker and Docker Compose.

## Architecture Overview

The application consists of 5 services:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React Client  │    │  Nginx Proxy    │    │  WebSocket      │
│   (Port 3000)   │◄───┤   (Port 80)     │◄───┤  Connector      │
└─────────────────┘    └─────────────────┘    │  (Port 8000)    │
                                              └─────────────────┘
                                                       │
                                                       ▼
                                              ┌─────────────────┐
                                              │  Python Server  │
                                              │  (Port 9999)    │
                                              └─────────────────┘
                                                       │
                                                       ▼
                                              ┌─────────────────┐
                                              │  PostgreSQL     │
                                              │  (Port 5432)    │
                                              └─────────────────┘
```

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- At least 2GB RAM available
- Ports 80, 3000, 5432, 8000, 9999 available

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo>
cd udp_chat

# Copy environment file
cp env.docker.sample .env

# Edit configuration if needed
nano .env
```

### 2. Start All Services

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service status
docker-compose ps
```

### 3. Access the Application

- **Web Interface**: http://localhost:3000
- **Direct WebSocket**: ws://localhost:8000/ws
- **Database**: localhost:5432

## Service Details

### PostgreSQL Database
- **Image**: postgres:15-alpine
- **Port**: 5432
- **Data**: Persistent volume `postgres_data`
- **Health Check**: Built-in PostgreSQL health check

### Python Server
- **Build**: Custom Dockerfile
- **Port**: 9999
- **Dependencies**: PostgreSQL
- **Health Check**: TCP connection test
- **Volumes**: `server_storage` for persistent data

### WebSocket Connector
- **Build**: Custom Dockerfile
- **Port**: 8000
- **Dependencies**: Python Server
- **Health Check**: HTTP endpoint check

### React Client
- **Build**: Multi-stage (Node.js + Nginx)
- **Port**: 3000
- **Dependencies**: WebSocket Connector
- **Health Check**: HTTP endpoint check

### Nginx Reverse Proxy
- **Image**: nginx:alpine
- **Port**: 80 (HTTP), 443 (HTTPS)
- **Features**: Load balancing, SSL termination, compression
- **Dependencies**: All services

## Configuration

### Environment Variables

Key environment variables in `.env`:

```env
# Database
DB_NAME=udpchat
DB_USER=udpchat_user
DB_PASSWORD=your_secure_password

# Ports
CLIENT_PORT=3000
CONNECTOR_PORT=8000
SERVER_PORT=9999
NGINX_PORT=80

# AI Configuration
OPENAI_API_KEY=your_openai_key
AI_MODE=ollama
```

### Custom Configuration

#### Database Configuration
Edit `server/db/schema.sql` for database schema changes.

#### Nginx Configuration
Edit `nginx/nginx.conf` for reverse proxy settings.

#### Client Configuration
Edit `client/nginx.conf` for client-specific Nginx settings.

## Development Mode

### Run Individual Services

```bash
# Start only database
docker-compose up -d postgresql

# Start server with database
docker-compose up -d postgresql server

# Start all services
docker-compose up -d
```

### Development with Live Reload

```bash
# For client development
cd client
npm run dev

# For server development
cd server
python main.py start

# For connector development
cd connector
npm run dev
```

### Debugging

```bash
# View logs for specific service
docker-compose logs -f server

# Execute commands in running container
docker-compose exec server bash
docker-compose exec postgresql psql -U udpchat_user -d udpchat

# Restart specific service
docker-compose restart server
```

## Production Deployment

### 1. Security Hardening

```bash
# Generate strong passwords
openssl rand -base64 32

# Update .env with secure passwords
# Enable SSL certificates in nginx/nginx.conf
# Set DEBUG=False
```

### 2. Resource Limits

Add to `docker-compose.yml`:

```yaml
services:
  server:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
```

### 3. SSL/HTTPS Setup

```bash
# Generate SSL certificates
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem

# Uncomment SSL server block in nginx/nginx.conf
# Update .env with NGINX_SSL_PORT=443
```

### 4. Monitoring and Logging

```bash
# View resource usage
docker stats

# Set up log rotation
# Add monitoring tools (Prometheus, Grafana)
# Configure health checks
```

## Maintenance

### Backup Database

```bash
# Create backup
docker-compose exec postgresql pg_dump -U udpchat_user udpchat > backup.sql

# Restore backup
docker-compose exec -T postgresql psql -U udpchat_user udpchat < backup.sql
```

### Update Application

```bash
# Pull latest changes
git pull

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Clean Up

```bash
# Remove unused containers and images
docker system prune -a

# Remove specific volumes
docker volume rm udp_chat_postgres_data
```

## Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check what's using ports
netstat -tulpn | grep :80
lsof -i :80

# Change ports in .env
CLIENT_PORT=3001
```

#### Database Connection Issues
```bash
# Check database logs
docker-compose logs postgresql

# Test database connection
docker-compose exec server python test_postgresql.py
```

#### Memory Issues
```bash
# Check memory usage
docker stats

# Increase Docker memory limit
# Restart Docker Desktop
```

#### Service Health Checks
```bash
# Check all service health
docker-compose ps

# View health check logs
docker inspect udpchat_server | grep -A 10 Health
```

### Log Analysis

```bash
# View all logs
docker-compose logs

# Filter logs by service and time
docker-compose logs --since=1h server

# Follow logs in real-time
docker-compose logs -f --tail=100
```

### Performance Tuning

#### Database Optimization
```sql
-- Connect to database
docker-compose exec postgresql psql -U udpchat_user -d udpchat

-- Check query performance
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';

-- Update statistics
ANALYZE;
```

#### Application Optimization
```bash
# Monitor resource usage
docker stats --no-stream

# Adjust container limits
# Optimize Dockerfile layers
# Use multi-stage builds
```

## Scaling

### Horizontal Scaling

```yaml
# Scale specific services
docker-compose up -d --scale connector=3

# Use load balancer for multiple instances
# Implement Redis for session sharing
# Use database connection pooling
```

### Vertical Scaling

```yaml
# Increase resource limits
services:
  server:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
```

## Security Considerations

1. **Change default passwords** in production
2. **Enable SSL/TLS** for HTTPS
3. **Use secrets management** for sensitive data
4. **Implement network segmentation**
5. **Regular security updates**
6. **Monitor for vulnerabilities**
7. **Backup encryption**

## Support

For issues and questions:

1. Check the logs: `docker-compose logs`
2. Verify configuration: `docker-compose config`
3. Test individual services
4. Check resource usage: `docker stats`
5. Review this documentation

The Docker setup provides a robust, scalable foundation for the UDPChat-AI application with proper health checks, logging, and monitoring capabilities.
