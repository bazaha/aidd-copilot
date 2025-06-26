#!/bin/bash

# Stop Script for AI Drug Discovery Agent

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="$PROJECT_DIR/logs"

echo -e "${RED}🛑 Stopping AI Drug Discovery Agent services...${NC}"

# Function to stop service by PID file
stop_service() {
    local service_name=$1
    local pid_file=$2
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}Stopping $service_name (PID: $pid)...${NC}"
            kill "$pid"
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${YELLOW}Force killing $service_name...${NC}"
                kill -9 "$pid" 2>/dev/null || true
            fi
            echo -e "${GREEN}✅ $service_name stopped${NC}"
        else
            echo -e "${YELLOW}⚠️  $service_name was not running${NC}"
        fi
        rm -f "$pid_file"
    else
        echo -e "${YELLOW}⚠️  No PID file found for $service_name${NC}"
    fi
}

# Stop Web Server
stop_service "Web Server" "$PID_DIR/web_server.pid"

# Stop MCP Gateway
stop_service "MCP Gateway" "$PID_DIR/mcp_gateway.pid"

# Stop Fake API Server
stop_service "Fake API Server" "$PID_DIR/fake_api.pid"

# Kill any remaining processes by port
echo -e "${YELLOW}Checking for remaining processes on known ports...${NC}"

# Kill processes on port 8080 (Web Server)
if lsof -ti:8080 >/dev/null 2>&1; then
    echo -e "${YELLOW}Killing processes on port 8080...${NC}"
    lsof -ti:8080 | xargs kill -9 2>/dev/null || true
fi

# Kill processes on port 8088 (MCP Gateway)
if lsof -ti:8088 >/dev/null 2>&1; then
    echo -e "${YELLOW}Killing processes on port 8088...${NC}"
    lsof -ti:8088 | xargs kill -9 2>/dev/null || true
fi

# Kill processes on port 8288 (Fake API)
if lsof -ti:8288 >/dev/null 2>&1; then
    echo -e "${YELLOW}Killing processes on port 8288...${NC}"
    lsof -ti:8288 | xargs kill -9 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}✅ All services have been stopped${NC}"
echo ""
