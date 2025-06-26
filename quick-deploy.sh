#!/bin/bash

# Quick Deploy Script for AI Drug Discovery Agent
# This is a simplified version for quick deployment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$PROJECT_DIR/venv"

echo -e "${GREEN}🚀 AI Drug Discovery Agent - Quick Deploy${NC}"
echo "Project directory: $PROJECT_DIR"

# Function to check if port is in use
check_port() {
    if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Port $1 is already in use${NC}"
        return 1
    fi
    return 0
}

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${GREEN}📦 Creating virtual environment...${NC}"
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
echo -e "${GREEN}🔧 Activating virtual environment...${NC}"
source "$VENV_DIR/bin/activate"

# Install dependencies
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    echo -e "${GREEN}📥 Installing dependencies...${NC}"
    pip install --upgrade pip
    pip install -r "$PROJECT_DIR/requirements.txt"
else
    echo -e "${GREEN}📥 Installing basic dependencies...${NC}"
    pip install --upgrade pip
    pip install flask flask-cors fastapi uvicorn requests aiohttp python-multipart
fi

# Set environment variables
export PYTHONPATH="$PROJECT_DIR:$PYTHONPATH"

# Create logs directory
mkdir -p "$PROJECT_DIR/logs"

echo -e "${GREEN}🌐 Starting services...${NC}"

# Check ports
check_port 8288 || echo -e "${YELLOW}Will attempt to start Fake API on port 8288 anyway${NC}"
check_port 8088 || echo -e "${YELLOW}Will attempt to start MCP Gateway on port 8088 anyway${NC}"
check_port 8080 || echo -e "${YELLOW}Will attempt to start Web Server on port 8080 anyway${NC}"

# Start Fake API Server
echo -e "${GREEN}🔬 Starting Fake API Server...${NC}"
cd "$PROJECT_DIR"
python3 fake_apis/fake_api_server.py > logs/fake_api.log 2>&1 &
FAKE_API_PID=$!
echo "Fake API Server PID: $FAKE_API_PID"
sleep 2

# Start MCP Gateway
echo -e "${GREEN}🧠 Starting MCP Gateway...${NC}"
python3 start_services.py > logs/mcp_gateway.log 2>&1 &
MCP_PID=$!
echo "MCP Gateway PID: $MCP_PID"
sleep 3

# Start Web Server
echo -e "${GREEN}🌍 Starting Web Server...${NC}"
cd "$PROJECT_DIR/web_interface"
python3 -m http.server 8080 > ../logs/web_server.log 2>&1 &
WEB_PID=$!
echo "Web Server PID: $WEB_PID"

# Save PIDs for later cleanup
echo "$FAKE_API_PID" > "$PROJECT_DIR/logs/fake_api.pid"
echo "$MCP_PID" > "$PROJECT_DIR/logs/mcp_gateway.pid"
echo "$WEB_PID" > "$PROJECT_DIR/logs/web_server.pid"

echo ""
echo -e "${GREEN}✅ All services started successfully!${NC}"
echo ""
echo "🌐 Access the application at:"
echo "   • Web Interface: http://localhost:8080"
echo "   • MCP Gateway:   http://localhost:8088"
echo "   • Fake API:      http://localhost:8288"
echo ""
echo "📝 Log files are in: $PROJECT_DIR/logs/"
echo ""
echo "🛑 To stop all services, run:"
echo "   kill $FAKE_API_PID $MCP_PID $WEB_PID"
echo "   or use: ./deploy.sh stop"
echo ""
echo -e "${GREEN}🎉 Deployment completed!${NC}"
