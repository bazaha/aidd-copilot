# Deployment Scripts

This directory contains several deployment scripts for the AI Drug Discovery Agent.

## Quick Start

For a quick deployment, use:

```bash
./quick-deploy.sh
```

This will:
- Create a virtual environment
- Install dependencies 
- Start all services
- Display access URLs

## Full Deployment

For a complete setup with more options:

```bash
# First time setup
./deploy.sh setup

# Start services
./deploy.sh start

# Check status
./deploy.sh status

# Stop services
./deploy.sh stop
```

## Scripts Overview

### `deploy.sh` - Main Deployment Script
The comprehensive deployment script with full functionality:
- `./deploy.sh setup` - Complete environment setup
- `./deploy.sh start` - Start all services
- `./deploy.sh stop` - Stop all services  
- `./deploy.sh restart` - Restart all services
- `./deploy.sh status` - Show service status
- `./deploy.sh logs` - Show recent logs
- `./deploy.sh clean` - Clean up and stop services

### `quick-deploy.sh` - Quick Start Script
Simplified script for immediate deployment:
- Sets up environment automatically
- Starts all services in background
- Displays access information

### `stop-services.sh` - Stop Script
Stops all running services:
- Gracefully stops all services
- Kills remaining processes on known ports
- Cleans up PID files

## Services

The deployment scripts start these services:

1. **Fake API Server** (Port 8288)
   - Provides mock external API responses
   - Used for development and demo purposes

2. **MCP Gateway** (Port 8088) 
   - Model Context Protocol server
   - Handles AI agent requests
   - Coordinates with various tools

3. **Web Server** (Port 8080)
   - Serves the web interface
   - Simple HTTP server for static files

## Access URLs

After deployment, access the application at:
- **Web Interface**: http://localhost:8080
- **MCP Gateway**: http://localhost:8088  
- **Fake API**: http://localhost:8288

## Keyboard Shortcuts

- **Ctrl/Cmd + ,** - Open configuration panel
- **Escape** - Close configuration panel
- **Enter** - Send message (Shift+Enter for new line)

## Configuration

The application supports multiple configuration methods:

### 1. UI Configuration (Recommended)
- Click the gear icon (⚙️) in the top-right corner
- Modify API endpoints and OpenAI settings
- Settings are automatically saved to browser localStorage
- Test connections before saving

### 2. Configuration File
Create or modify `web_interface/config.json`:
```json
{
  "API_BASE": "http://localhost:8088",
  "FAKE_API_BASE": "http://localhost:8288", 
  "OPENAI_API_KEY": "",
  "OPENAI_API_BASE": "https://api.openai.com/v1"
}
```

### 3. Environment-Specific Configs
- `config.json` - Default/development configuration
- `config.production.json` - Production template
- Copy and rename for different environments

### Configuration Priority
1. Browser localStorage (set via UI)
2. config.json file
3. Built-in defaults

### Environment Variables
You can customize ports and settings by setting environment variables:

```bash
export MCP_PORT=8088
export FAKE_API_PORT=8288  
export WEB_PORT=8080
./deploy.sh start
```

### Requirements
- Python 3.8 or higher
- pip package manager
- Available ports: 8080, 8088, 8288

### Dependencies
Dependencies are managed via `requirements.txt`. Core dependencies include:
- Flask and FastAPI for web services
- aiohttp and requests for HTTP clients
- Scientific computing libraries (numpy, pandas, etc.)

## Logs

Service logs are stored in the `logs/` directory:
- `logs/fake_api.log` - Fake API server logs
- `logs/mcp_gateway.log` - MCP gateway logs  
- `logs/web_server.log` - Web server logs

## Troubleshooting

### Port Already in Use
If you see port conflicts:
```bash
# Stop all services first
./stop-services.sh

# Or kill specific processes
lsof -ti:8080 | xargs kill -9
```

### Python Environment Issues
```bash
# Clean up and recreate environment
rm -rf venv/
./deploy.sh setup
```

### Service Won't Start
Check logs for errors:
```bash
./deploy.sh logs
# or
tail -f logs/service_name.log
```

## Development

For development with auto-reload:
```bash
# Start services individually with debug mode
source venv/bin/activate
export FLASK_ENV=development
python fake_apis/fake_api_server.py
```

## Production Notes

For production deployment:
1. Use a proper WSGI server (gunicorn, uwsgi)
2. Set up reverse proxy (nginx, Apache)
3. Configure SSL/TLS certificates
4. Set up monitoring and logging
5. Use environment-specific configuration files
