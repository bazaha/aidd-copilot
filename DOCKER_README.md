# Docker Deployment Guide

This guide provides comprehensive instructions for deploying the AI Drug Discovery Agent using Docker.

## Quick Start

### Prerequisites
- Docker (version 20.10 or higher)
- Docker Compose (version 2.0 or higher)
- 4GB RAM minimum, 8GB recommended

### One-Command Deployment

```bash
# Make the script executable
chmod +x docker-deploy.sh

# Build and start all services
./docker-deploy.sh build && ./docker-deploy.sh start
```

Access the application at:
- **Web Interface**: http://localhost:8080
- **MCP Gateway**: http://localhost:8088
- **Fake API**: http://localhost:8288

## Deployment Options

### 1. Docker Compose (Recommended)

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### 2. Production Deployment with Nginx

```bash
# Start with nginx reverse proxy
./docker-deploy.sh prod

# Access via nginx
# http://localhost:80
```

### 3. Development Mode

```bash
# Start with live reload
./docker-deploy.sh dev
```

## Docker Deploy Script Commands

The `docker-deploy.sh` script provides comprehensive Docker management:

```bash
./docker-deploy.sh [COMMAND]

Commands:
  build       Build Docker image
  start       Start services with docker-compose
  stop        Stop all services
  restart     Restart all services
  status      Show service status
  logs [SVC]  Show logs (optionally for specific service)
  dev         Run in development mode
  prod        Run in production mode with nginx
  shell       Enter container shell
  cleanup     Clean up Docker resources
  config      Update configuration
  backup      Create backup of data and configuration
  help        Show help message
```

### Examples

```bash
# Build and start
./docker-deploy.sh build
./docker-deploy.sh start

# Show service status
./docker-deploy.sh status

# View logs for specific service
./docker-deploy.sh logs ai-drug-discovery

# Enter container shell for debugging
./docker-deploy.sh shell

# Clean up everything
./docker-deploy.sh cleanup
```

## Configuration

### Environment Variables

Create a `.env` file from the example:

```bash
cp .env.example .env
# Edit .env with your settings
```

Key environment variables:

```bash
# Application ports
MCP_PORT=8088
FAKE_API_PORT=8288
WEB_PORT=8080

# Python environment
FLASK_ENV=production
PYTHONPATH=/app

# OpenAI API (optional)
OPENAI_API_KEY=your_api_key_here
```

### Application Configuration

The application configuration is managed via `web_interface/config.json`:

```json
{
  "API_BASE": "http://localhost:8088",
  "FAKE_API_BASE": "http://localhost:8288",
  "OPENAI_API_KEY": "",
  "OPENAI_API_BASE": "https://api.openai.com/v1"
}
```

### Docker Compose Configuration

The `docker-compose.yml` includes:

- **Main Application**: AI Drug Discovery Agent
- **Nginx**: Optional reverse proxy for production
- **Volumes**: Persistent storage for logs and temporary files
- **Networks**: Isolated network for services
- **Health Checks**: Automatic service health monitoring

## Service Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │    │     Nginx       │    │  AI Drug        │
│                 │───▶│  (Port 80/443)  │───▶│  Discovery      │
│  localhost:8080 │    │  Reverse Proxy  │    │  Agent          │
└─────────────────┘    └─────────────────┘    │  (Port 8080)    │
                                              └─────────────────┘
                                                        │
                                              ┌─────────────────┐
                                              │  MCP Gateway    │
                                              │  (Port 8088)    │
                                              └─────────────────┘
                                                        │
                                              ┌─────────────────┐
                                              │  Fake API       │
                                              │  (Port 8288)    │
                                              └─────────────────┘
```

## Docker Images

### Base Image
- **Python 3.11 Slim**: Optimized Python runtime
- **Security**: Non-root user execution
- **Size**: ~200MB final image

### Multi-stage Build
The Dockerfile uses best practices:
- Separate dependency installation layer
- Security hardening
- Minimal attack surface
- Efficient layer caching

## Health Checks

### Application Health
The application includes built-in health checks:

```bash
# Check application health
curl http://localhost:8088/health

# Check via Docker
docker-compose ps
```

### Service Monitoring
- **Automatic Restarts**: Services restart on failure
- **Health Check Intervals**: 30-second checks
- **Startup Grace Period**: 60 seconds
- **Failure Threshold**: 3 consecutive failures

## Networking

### Port Mapping
- **8080**: Web Interface
- **8088**: MCP Gateway API
- **8288**: Fake API Server
- **80/443**: Nginx (production mode)

### Internal Communication
Services communicate via Docker's internal network:
- Service discovery by name
- Automatic load balancing
- Network isolation

## Volumes

### Persistent Storage
```yaml
volumes:
  - ./logs:/app/logs        # Application logs
  - ./tmp:/app/tmp          # Temporary files
```

### Configuration
```yaml
volumes:
  - ./web_interface/config.json:/app/web_interface/config.json
```

## Security

### Container Security
- **Non-root execution**: Application runs as `appuser`
- **Minimal permissions**: Read-only where possible
- **Network isolation**: Services in private network
- **Resource limits**: CPU and memory constraints

### Nginx Security Headers
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- X-XSS-Protection: enabled
- Strict-Transport-Security (HTTPS)

### Rate Limiting
- API endpoints: 10 requests/second
- Web interface: 30 requests/second
- Burst protection: Configurable limits

## Troubleshooting

### Common Issues

#### Port Conflicts
```bash
# Check port usage
lsof -i :8080

# Stop conflicting services
./docker-deploy.sh stop
```

#### Service Won't Start
```bash
# Check logs
./docker-deploy.sh logs

# Check service status
docker-compose ps

# Restart specific service
docker-compose restart ai-drug-discovery
```

#### Memory Issues
```bash
# Check Docker resources
docker stats

# Increase memory limits in docker-compose.yml
```

#### Container Shell Access
```bash
# Enter running container
./docker-deploy.sh shell

# Debug with temporary container
docker run -it --rm ai-drug-discovery-agent:latest /bin/bash
```

### Debug Mode

Enable debug logging:

```bash
# Set environment variable
export LOG_LEVEL=DEBUG

# Restart services
./docker-deploy.sh restart
```

### Log Analysis

```bash
# Show recent logs
./docker-deploy.sh logs

# Follow logs in real-time
docker-compose logs -f

# Show logs for specific service
docker-compose logs -f ai-drug-discovery
```

## Production Deployment

### SSL/TLS Configuration

1. Obtain SSL certificates
2. Place certificates in `ssl/` directory
3. Update `nginx.conf` with certificate paths
4. Enable HTTPS server block

```bash
# Start with production profile
./docker-deploy.sh prod
```

### Environment Hardening

1. **Use production configuration**:
   ```bash
   cp web_interface/config.production.json web_interface/config.json
   ```

2. **Set secure environment variables**:
   ```bash
   export FLASK_ENV=production
   export FLASK_DEBUG=false
   ```

3. **Enable security features**:
   - Rate limiting
   - HTTPS enforcement
   - Security headers
   - Input validation

### Monitoring

Consider adding:
- **Prometheus**: Metrics collection
- **Grafana**: Visualization
- **ELK Stack**: Log aggregation
- **Health check endpoints**: Automated monitoring

### Backup Strategy

```bash
# Create backup
./docker-deploy.sh backup

# Backup includes:
# - Application logs
# - Configuration files
# - Docker volumes
```

## Development

### Local Development with Docker

```bash
# Build development image
docker build -t ai-drug-discovery-dev .

# Start development environment
./docker-deploy.sh dev

# Mount source code for live editing
docker-compose -f docker-compose.dev.yml up
```

### Hot Reload

For development with hot reload, mount the source directory:

```yaml
volumes:
  - .:/app
  - /app/venv  # Exclude virtual environment
```

## Performance Optimization

### Resource Limits

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 2G
    reservations:
      cpus: '0.5'
      memory: 512M
```

### Caching

- **Docker layer caching**: Optimized Dockerfile
- **Application caching**: Redis integration ready
- **Static file caching**: Nginx configuration

## Updates and Maintenance

### Updating the Application

```bash
# Pull latest changes
git pull

# Rebuild and restart
./docker-deploy.sh build
./docker-deploy.sh restart
```

### Container Maintenance

```bash
# Clean up unused resources
./docker-deploy.sh cleanup

# Update base images
docker-compose pull
docker-compose up -d
```

## Support

For issues with Docker deployment:

1. Check the logs: `./docker-deploy.sh logs`
2. Verify system requirements
3. Consult troubleshooting section
4. Check Docker documentation

---

This Docker deployment provides a production-ready containerized solution for the AI Drug Discovery Agent with comprehensive monitoring, security, and management capabilities.
