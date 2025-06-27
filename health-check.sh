#!/bin/bash

# Health check script for Docker container
# This script verifies that all services are running correctly

set -e

# Configuration
MCP_PORT=${MCP_PORT:-8088}
FAKE_API_PORT=${FAKE_API_PORT:-8288}
WEB_PORT=${WEB_PORT:-8080}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Function to check if a port is responding
check_port() {
    local port=$1
    local service_name=$2
    local timeout=5
    
    if curl -f -s --max-time $timeout "http://localhost:$port" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $service_name (port $port) is healthy"
        return 0
    else
        echo -e "${RED}✗${NC} $service_name (port $port) is not responding"
        return 1
    fi
}

# Function to check MCP Gateway health endpoint
check_mcp_health() {
    local timeout=5
    
    if curl -f -s --max-time $timeout "http://localhost:$MCP_PORT/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} MCP Gateway health endpoint is responding"
        return 0
    else
        echo -e "${RED}✗${NC} MCP Gateway health endpoint is not responding"
        return 1
    fi
}

# Function to check if all services are healthy
check_all_services() {
    local failed=0
    
    echo "🔍 Checking service health..."
    echo ""
    
    # Check Web Server
    if ! check_port $WEB_PORT "Web Server"; then
        failed=$((failed + 1))
    fi
    
    # Check MCP Gateway
    if ! check_port $MCP_PORT "MCP Gateway"; then
        failed=$((failed + 1))
    fi
    
    # Check MCP Gateway health endpoint
    if ! check_mcp_health; then
        failed=$((failed + 1))
    fi
    
    # Check Fake API Server
    if ! check_port $FAKE_API_PORT "Fake API Server"; then
        failed=$((failed + 1))
    fi
    
    echo ""
    
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}🎉 All services are healthy!${NC}"
        return 0
    else
        echo -e "${RED}❌ $failed service(s) failed health check${NC}"
        return 1
    fi
}

# Function to show service information
show_service_info() {
    echo "📊 Service Information:"
    echo "  • Web Server:     http://localhost:$WEB_PORT"
    echo "  • MCP Gateway:    http://localhost:$MCP_PORT"
    echo "  • Fake API:       http://localhost:$FAKE_API_PORT"
    echo "  • Health Check:   http://localhost:$MCP_PORT/health"
    echo ""
}

# Main execution
main() {
    case "${1:-check}" in
        check|health)
            show_service_info
            check_all_services
            ;;
        info)
            show_service_info
            ;;
        wait)
            # Wait for services to be ready (useful for container startup)
            local max_attempts=30
            local attempt=1
            
            echo "⏳ Waiting for services to be ready..."
            
            while [ $attempt -le $max_attempts ]; do
                if check_all_services > /dev/null 2>&1; then
                    echo -e "${GREEN}✅ All services are ready!${NC}"
                    show_service_info
                    exit 0
                fi
                
                echo "Attempt $attempt/$max_attempts - Waiting 2 seconds..."
                sleep 2
                attempt=$((attempt + 1))
            done
            
            echo -e "${RED}❌ Timeout waiting for services to be ready${NC}"
            check_all_services
            exit 1
            ;;
        *)
            echo "Usage: $0 [check|health|info|wait]"
            echo ""
            echo "Commands:"
            echo "  check/health  Check if all services are healthy (default)"
            echo "  info          Show service information"
            echo "  wait          Wait for services to be ready"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
