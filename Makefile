# UDPChat-AI Docker Management Makefile

.PHONY: help build up down restart logs clean dev prod test backup restore

# Default target
help:
	@echo "UDPChat-AI Docker Management"
	@echo "=========================="
	@echo ""
	@echo "Available commands:"
	@echo "  make build     - Build all Docker images"
	@echo "  make up        - Start all services (production)"
	@echo "  make dev       - Start all services (development)"
	@echo "  make down      - Stop all services"
	@echo "  make restart   - Restart all services"
	@echo "  make logs      - View logs for all services"
	@echo "  make logs-f    - Follow logs for all services"
	@echo "  make clean     - Clean up containers, images, and volumes"
	@echo "  make test      - Run tests"
	@echo "  make backup    - Backup database"
	@echo "  make restore   - Restore database from backup"
	@echo "  make status    - Show service status"
	@echo "  make shell     - Open shell in server container"
	@echo "  make db-shell  - Open PostgreSQL shell"
	@echo ""

# Build all images
build:
	@echo "Building all Docker images..."
	docker-compose build --no-cache

# Production deployment
up:
	@echo "Starting production services..."
	docker-compose up -d
	@echo "Services started. Access at http://localhost:3000"

# Development deployment
dev:
	@echo "Starting development services..."
	docker-compose -f docker-compose.dev.yml up -d
	@echo "Development services started. Access at http://localhost:3000"

# Stop all services
down:
	@echo "Stopping all services..."
	docker-compose down
	docker-compose -f docker-compose.dev.yml down

# Restart all services
restart:
	@echo "Restarting all services..."
	docker-compose restart

# View logs
logs:
	@echo "Showing logs for all services..."
	docker-compose logs

# Follow logs
logs-f:
	@echo "Following logs for all services..."
	docker-compose logs -f

# Clean up
clean:
	@echo "Cleaning up Docker resources..."
	docker-compose down -v
	docker-compose -f docker-compose.dev.yml down -v
	docker system prune -f
	docker volume prune -f

# Run tests
test:
	@echo "Running tests..."
	docker-compose exec server python test_postgresql.py

# Backup database
backup:
	@echo "Backing up database..."
	docker-compose exec postgresql pg_dump -U udpchat_user udpchat > backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "Backup created: backup_$(shell date +%Y%m%d_%H%M%S).sql"

# Restore database
restore:
	@echo "Available backups:"
	@ls -la backup_*.sql 2>/dev/null || echo "No backups found"
	@echo ""
	@read -p "Enter backup filename: " backup_file; \
	if [ -f "$$backup_file" ]; then \
		echo "Restoring from $$backup_file..."; \
		docker-compose exec -T postgresql psql -U udpchat_user udpchat < $$backup_file; \
		echo "Database restored successfully"; \
	else \
		echo "Backup file not found"; \
	fi

# Show service status
status:
	@echo "Service Status:"
	@echo "==============="
	docker-compose ps

# Open shell in server container
shell:
	@echo "Opening shell in server container..."
	docker-compose exec server bash

# Open PostgreSQL shell
db-shell:
	@echo "Opening PostgreSQL shell..."
	docker-compose exec postgresql psql -U udpchat_user -d udpchat

# Individual service management
up-db:
	@echo "Starting database only..."
	docker-compose up -d postgresql

up-server:
	@echo "Starting server with database..."
	docker-compose up -d postgresql server

up-connector:
	@echo "Starting connector with dependencies..."
	docker-compose up -d postgresql server connector

up-client:
	@echo "Starting all services including client..."
	docker-compose up -d

# Development helpers
dev-logs:
	@echo "Following development logs..."
	docker-compose -f docker-compose.dev.yml logs -f

dev-shell:
	@echo "Opening shell in development server container..."
	docker-compose -f docker-compose.dev.yml exec server bash

# Health checks
health:
	@echo "Checking service health..."
	@docker-compose ps
	@echo ""
	@echo "Health check details:"
	@docker inspect udpchat_server | jq '.[0].State.Health' 2>/dev/null || echo "jq not installed, showing raw output:"
	@docker inspect udpchat_server | grep -A 10 Health || echo "Health check not available"

# Quick setup for new users
setup:
	@echo "Setting up UDPChat-AI for the first time..."
	@if [ ! -f .env ]; then \
		cp env.docker.sample .env; \
		echo "Created .env file from template. Please edit it with your configuration."; \
	fi
	@echo "Building and starting services..."
	@make build
	@make up
	@echo "Setup complete! Access the application at http://localhost:3000"

# Production deployment helpers
prod-build:
	@echo "Building production images..."
	docker-compose build --no-cache --parallel

prod-deploy:
	@echo "Deploying to production..."
	@make prod-build
	@make up
	@echo "Production deployment complete!"

# Monitoring
monitor:
	@echo "Monitoring resource usage..."
	@watch -n 2 'docker stats --no-stream'

# Security scan
security-scan:
	@echo "Running security scan on images..."
	@docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy image udpchat_server:latest || echo "Trivy not available"
