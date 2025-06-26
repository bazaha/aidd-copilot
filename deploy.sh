#!/bin/bash

# AI Drug Discovery Agent - Deployment Script
# This script sets up the environment and starts all necessary services

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="AI Drug Discovery Agent"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_VERSION="3.11"
VENV_DIR="$PROJECT_DIR/venv"
LOG_DIR="$PROJECT_DIR/logs"
PID_DIR="$PROJECT_DIR/pids"

# Default ports
MCP_PORT=8088
FAKE_API_PORT=8288
WEB_PORT=8080

# Environment variables
export PYTHONPATH="$PROJECT_DIR:$PYTHONPATH"
export NODE_ENV="production"
export FLASK_ENV="production"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is available
is_port_available() {
    ! nc -z localhost "$1" 2>/dev/null
}

# Function to wait for service to be ready
wait_for_service() {
    local port=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $service_name to start on port $port..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost "$port" 2>/dev/null; then
            print_status "$service_name is ready!"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    print_error "Timeout waiting for $service_name to start"
    return 1
}

# Function to create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    mkdir -p "$LOG_DIR"
    mkdir -p "$PID_DIR"
    mkdir -p "$PROJECT_DIR/tmp"
}

# Function to check system requirements
check_requirements() {
    print_header "Checking system requirements..."
    
    # Check Python
    if command_exists python3; then
        PYTHON_CMD="python3"
    elif command_exists python; then
        PYTHON_CMD="python"
    else
        print_error "Python is not installed. Please install Python 3.8 or higher."
        exit 1
    fi
    
    PYTHON_VER=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2 | cut -d'.' -f1,2)
    print_status "Found Python $PYTHON_VER"
    
    # Check pip
    if ! command_exists pip3 && ! command_exists pip; then
        print_error "pip is not installed. Please install pip."
        exit 1
    fi
    
    # Check if ports are available
    if ! is_port_available $MCP_PORT; then
        print_warning "Port $MCP_PORT is already in use. MCP server may fail to start."
    fi
    
    if ! is_port_available $FAKE_API_PORT; then
        print_warning "Port $FAKE_API_PORT is already in use. Fake API server may fail to start."
    fi
    
    if ! is_port_available $WEB_PORT; then
        print_warning "Port $WEB_PORT is already in use. Web server may fail to start."
    fi
    
    print_status "System requirements check completed."
}

# Function to setup Python virtual environment
setup_venv() {
    print_header "Setting up Python virtual environment..."
    
    if [ ! -d "$VENV_DIR" ]; then
        print_status "Creating virtual environment..."
        $PYTHON_CMD -m venv "$VENV_DIR"
    else
        print_status "Virtual environment already exists."
    fi
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    print_status "Upgrading pip..."
    pip install --upgrade pip
    
    print_status "Virtual environment setup completed."
}

# Function to install Python dependencies
install_dependencies() {
    print_header "Installing Python dependencies..."
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Check if requirements.txt exists
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
        print_status "Installing dependencies from requirements.txt..."
        pip install -r "$PROJECT_DIR/requirements.txt"
    else
        print_warning "requirements.txt not found, installing basic dependencies..."
        # Core dependencies
        print_status "Installing core dependencies..."
        pip install flask flask-cors
        pip install fastapi uvicorn
        pip install requests aiohttp
        pip install python-multipart
        
        # Development dependencies
        print_status "Installing development dependencies..."
        pip install pytest pytest-asyncio
        pip install black flake8
        
        # Optional scientific dependencies
        print_status "Installing scientific dependencies (may take a while)..."
        pip install numpy pandas || print_warning "Failed to install numpy/pandas"
        pip install scipy scikit-learn || print_warning "Failed to install scipy/scikit-learn"
    fi
    
    print_status "Dependencies installation completed."
}

# Function to setup environment variables
setup_environment() {
    print_header "Setting up environment variables..."
    
    # Create .env file if it doesn't exist
    ENV_FILE="$PROJECT_DIR/.env"
    if [ ! -f "$ENV_FILE" ]; then
        print_status "Creating .env file..."
        cat > "$ENV_FILE" << EOF
# AI Drug Discovery Agent Configuration
PROJECT_DIR=$PROJECT_DIR
PYTHONPATH=$PROJECT_DIR

# Server Configuration
MCP_PORT=$MCP_PORT
FAKE_API_PORT=$FAKE_API_PORT
WEB_PORT=$WEB_PORT

# Flask Configuration
FLASK_ENV=production
FLASK_DEBUG=false

# FastAPI Configuration
FASTAPI_ENV=production

# Logging Configuration
LOG_LEVEL=INFO
LOG_DIR=$LOG_DIR

# OpenAI Configuration (optional - add your API key here)
# OPENAI_API_KEY=your_api_key_here

# External API Configuration
EXTERNAL_API_TIMEOUT=30
MAX_RETRIES=3

# Development Configuration
DEVELOPMENT_MODE=false
EOF
        print_status ".env file created."
    else
        print_status ".env file already exists."
    fi
    
    # Source the environment file
    set -a  # automatically export all variables
    source "$ENV_FILE"
    set +a
}

# Function to start fake API server
start_fake_api() {
    print_header "Starting Fake API Server..."
    
    source "$VENV_DIR/bin/activate"
    
    local pid_file="$PID_DIR/fake_api.pid"
    local log_file="$LOG_DIR/fake_api.log"
    
    # Check if already running
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        print_warning "Fake API Server is already running (PID: $(cat "$pid_file"))"
        return 0
    fi
    
    # Start the server
    nohup $PYTHON_CMD "$PROJECT_DIR/fake_apis/fake_api_server.py" > "$log_file" 2>&1 &
    local pid=$!
    echo $pid > "$pid_file"
    
    print_status "Fake API Server started (PID: $pid)"
    wait_for_service $FAKE_API_PORT "Fake API Server"
}

# Function to start MCP gateway
start_mcp_gateway() {
    print_header "Starting MCP Gateway..."
    
    source "$VENV_DIR/bin/activate"
    
    local pid_file="$PID_DIR/mcp_gateway.pid"
    local log_file="$LOG_DIR/mcp_gateway.log"
    
    # Check if already running
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        print_warning "MCP Gateway is already running (PID: $(cat "$pid_file"))"
        return 0
    fi
    
    # Start the gateway
    cd "$PROJECT_DIR"
    nohup $PYTHON_CMD -c "
import sys
sys.path.insert(0, '$PROJECT_DIR')
from mcp_servers.manager import mcp_manager
import asyncio
asyncio.run(mcp_manager.start_server(host='0.0.0.0', port=$MCP_PORT))
" > "$log_file" 2>&1 &
    local pid=$!
    echo $pid > "$pid_file"
    
    print_status "MCP Gateway started (PID: $pid)"
    wait_for_service $MCP_PORT "MCP Gateway"
}

# Function to start web server
start_web_server() {
    print_header "Starting Web Server..."
    
    local pid_file="$PID_DIR/web_server.pid"
    local log_file="$LOG_DIR/web_server.log"
    
    # Check if already running
    if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        print_warning "Web Server is already running (PID: $(cat "$pid_file"))"
        return 0
    fi
    
    # Check if Python HTTP server or another web server is available
    if command_exists python3; then
        cd "$PROJECT_DIR/web_interface"
        nohup python3 -m http.server $WEB_PORT > "$log_file" 2>&1 &
        local pid=$!
        echo $pid > "$pid_file"
        print_status "Web Server started (PID: $pid)"
        wait_for_service $WEB_PORT "Web Server"
    else
        print_warning "Cannot start web server. Please serve the web_interface directory manually."
    fi
}

# Function to show service status
show_status() {
    print_header "Service Status:"
    
    # Check Fake API
    if [ -f "$PID_DIR/fake_api.pid" ] && kill -0 "$(cat "$PID_DIR/fake_api.pid")" 2>/dev/null; then
        print_status "✓ Fake API Server is running (PID: $(cat "$PID_DIR/fake_api.pid"), Port: $FAKE_API_PORT)"
    else
        print_error "✗ Fake API Server is not running"
    fi
    
    # Check MCP Gateway
    if [ -f "$PID_DIR/mcp_gateway.pid" ] && kill -0 "$(cat "$PID_DIR/mcp_gateway.pid")" 2>/dev/null; then
        print_status "✓ MCP Gateway is running (PID: $(cat "$PID_DIR/mcp_gateway.pid"), Port: $MCP_PORT)"
    else
        print_error "✗ MCP Gateway is not running"
    fi
    
    # Check Web Server
    if [ -f "$PID_DIR/web_server.pid" ] && kill -0 "$(cat "$PID_DIR/web_server.pid")" 2>/dev/null; then
        print_status "✓ Web Server is running (PID: $(cat "$PID_DIR/web_server.pid"), Port: $WEB_PORT)"
    else
        print_error "✗ Web Server is not running"
    fi
    
    echo ""
    print_header "Access URLs:"
    echo "  • Web Interface: http://localhost:$WEB_PORT"
    echo "  • MCP Gateway: http://localhost:$MCP_PORT"
    echo "  • Fake API: http://localhost:$FAKE_API_PORT"
    echo ""
    print_header "Log files are located in: $LOG_DIR"
}

# Function to stop all services
stop_services() {
    print_header "Stopping all services..."
    
    # Stop Web Server
    if [ -f "$PID_DIR/web_server.pid" ]; then
        local pid=$(cat "$PID_DIR/web_server.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            print_status "Web Server stopped (PID: $pid)"
        fi
        rm -f "$PID_DIR/web_server.pid"
    fi
    
    # Stop MCP Gateway
    if [ -f "$PID_DIR/mcp_gateway.pid" ]; then
        local pid=$(cat "$PID_DIR/mcp_gateway.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            print_status "MCP Gateway stopped (PID: $pid)"
        fi
        rm -f "$PID_DIR/mcp_gateway.pid"
    fi
    
    # Stop Fake API
    if [ -f "$PID_DIR/fake_api.pid" ]; then
        local pid=$(cat "$PID_DIR/fake_api.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            print_status "Fake API Server stopped (PID: $pid)"
        fi
        rm -f "$PID_DIR/fake_api.pid"
    fi
    
    print_status "All services stopped."
}

# Function to restart all services
restart_services() {
    print_header "Restarting all services..."
    stop_services
    sleep 2
    start_all_services
}

# Function to start all services
start_all_services() {
    start_fake_api
    sleep 2
    start_mcp_gateway
    sleep 2
    start_web_server
}

# Function to show help
show_help() {
    echo "AI Drug Discovery Agent - Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup       Setup environment and install dependencies"
    echo "  start       Start all services"
    echo "  stop        Stop all services"
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo "  logs        Show recent logs"
    echo "  clean       Clean up temporary files and stop services"
    echo "  help        Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  MCP_PORT      Port for MCP Gateway (default: 8088)"
    echo "  FAKE_API_PORT Port for Fake API Server (default: 8288)"
    echo "  WEB_PORT      Port for Web Server (default: 8080)"
    echo ""
}

# Function to show logs
show_logs() {
    print_header "Recent logs:"
    
    if [ -f "$LOG_DIR/fake_api.log" ]; then
        echo ""
        print_status "Fake API Server logs (last 20 lines):"
        tail -n 20 "$LOG_DIR/fake_api.log"
    fi
    
    if [ -f "$LOG_DIR/mcp_gateway.log" ]; then
        echo ""
        print_status "MCP Gateway logs (last 20 lines):"
        tail -n 20 "$LOG_DIR/mcp_gateway.log"
    fi
    
    if [ -f "$LOG_DIR/web_server.log" ]; then
        echo ""
        print_status "Web Server logs (last 20 lines):"
        tail -n 20 "$LOG_DIR/web_server.log"
    fi
}

# Function to clean up
cleanup() {
    print_header "Cleaning up..."
    stop_services
    
    # Clean temporary files
    rm -rf "$PROJECT_DIR/tmp"
    rm -rf "$PROJECT_DIR/__pycache__"
    find "$PROJECT_DIR" -name "*.pyc" -delete
    find "$PROJECT_DIR" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    
    print_status "Cleanup completed."
}

# Trap for cleanup on script exit
trap cleanup EXIT

# Main execution
main() {
    case "${1:-start}" in
        setup)
            print_header "Setting up $PROJECT_NAME..."
            create_directories
            check_requirements
            setup_venv
            install_dependencies
            setup_environment
            print_status "Setup completed successfully!"
            print_status "Run '$0 start' to start the services."
            ;;
        start)
            print_header "Starting $PROJECT_NAME..."
            create_directories
            setup_environment
            start_all_services
            show_status
            print_status "All services started successfully!"
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            show_status
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        clean)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Check if running as root (not recommended)
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root is not recommended for security reasons."
fi

# Run main function with all arguments
main "$@"
