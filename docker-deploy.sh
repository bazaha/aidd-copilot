#!/bin/bash

# Docker Deployment Script for AI Drug Discovery Agent
# This script provides easy Docker deployment commands

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="ai-drug-discovery"
IMAGE_NAME="ai-drug-discovery-agent"
CONTAINER_NAME="ai-drug-discovery-agent"

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
    echo -e "${BLUE}[DOCKER]${NC} $1"
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_warning "docker-compose is not installed. Installing via pip..."
        pip install docker-compose
    fi
}

# Function to build Docker image
build_image() {
    print_header "Building Docker image..."
    
    docker build -t $IMAGE_NAME:latest .
    
    if [ $? -eq 0 ]; then
        print_status "Docker image built successfully: $IMAGE_NAME:latest"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
}

# Function to start services with docker-compose
start_services() {
    print_header "Starting services with docker-compose..."
    
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_status "Services started successfully"
        show_access_info
    else
        print_error "Failed to start services"
        exit 1
    fi
}

# Function to stop services
stop_services() {
    print_header "Stopping services..."
    
    docker-compose down
    
    if [ $? -eq 0 ]; then
        print_status "Services stopped successfully"
    else
        print_error "Failed to stop services"
        exit 1
    fi
}

# Function to restart services
restart_services() {
    print_header "Restarting services..."
    
    docker-compose restart
    
    if [ $? -eq 0 ]; then
        print_status "Services restarted successfully"
        show_access_info
    else
        print_error "Failed to restart services"
        exit 1
    fi
}

# Function to show service status
show_status() {
    print_header "Service status:"
    
    docker-compose ps
}

# Function to show logs
show_logs() {
    service=${1:-""}
    
    if [ -z "$service" ]; then
        print_header "Showing logs for all services:"
        docker-compose logs -f
    else
        print_header "Showing logs for $service:"
        docker-compose logs -f $service
    fi
}

# Function to show access information
show_access_info() {
    echo ""
    print_status "🌐 Access the application at:"
    echo "   • Web Interface: http://localhost:8080"
    echo "   • MCP Gateway:   http://localhost:8088"
    echo "   • Fake API:      http://localhost:8288"
    echo ""
    print_status "📊 Health Check: http://localhost:8088/health"
    echo ""
}

# Function to run development mode
run_dev() {
    print_header "Starting in development mode..."
    
    docker-compose -f docker-compose.yml up --build
}

# Function to run production mode with nginx
run_prod() {
    print_header "Starting in production mode with nginx..."
    
    docker-compose --profile production up -d --build
    
    if [ $? -eq 0 ]; then
        print_status "Production services started successfully"
        echo ""
        print_status "🌐 Access the application at:"
        echo "   • Web Interface: http://localhost:80"
        echo "   • HTTPS (if configured): https://localhost:443"
        echo ""
    else
        print_error "Failed to start production services"
        exit 1
    fi
}

# Function to clean up Docker resources
cleanup() {
    print_header "Cleaning up Docker resources..."
    
    # Stop and remove containers
    docker-compose down -v --remove-orphans
    
    # Remove images
    docker rmi $IMAGE_NAME:latest 2>/dev/null || true
    
    # Remove unused volumes and networks
    docker volume prune -f
    docker network prune -f
    
    print_status "Cleanup completed"
}

# Function to enter container shell
shell() {
    print_header "Entering container shell..."
    
    if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        docker exec -it $CONTAINER_NAME /bin/bash
    else
        print_error "Container $CONTAINER_NAME is not running"
        exit 1
    fi
}

# Function to update configuration
update_config() {
    print_header "Updating configuration..."
    
    # Copy production config if it doesn't exist
    if [ ! -f "web_interface/config.json" ]; then
        cp web_interface/config.production.json web_interface/config.json
        print_status "Created config.json from production template"
    fi
    
    # Restart services to apply new configuration
    docker-compose restart
    
    print_status "Configuration updated and services restarted"
}

# Function to backup data
backup() {
    backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
    
    print_header "Creating backup in $backup_dir..."
    
    mkdir -p $backup_dir
    
    # Copy logs
    cp -r logs $backup_dir/ 2>/dev/null || true
    
    # Copy configuration
    cp web_interface/config*.json $backup_dir/ 2>/dev/null || true
    
    # Export Docker volumes
    docker run --rm -v ai-drug-discovery_logs:/data -v $(pwd)/$backup_dir:/backup alpine tar czf /backup/logs.tar.gz -C /data .
    
    print_status "Backup created in $backup_dir"
}

# Function to show help
show_help() {
    echo "AI Drug Discovery Agent - Docker Deployment Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build       Build Docker image"
    echo "  start       Start services with docker-compose"
    echo "  stop        Stop all services"
    echo "  restart     Restart all services"
    echo "  status      Show service status"
    echo "  logs [SVC]  Show logs (optionally for specific service)"
    echo "  dev         Run in development mode with live reload"
    echo "  prod        Run in production mode with nginx"
    echo "  shell       Enter container shell"
    echo "  cleanup     Clean up Docker resources"
    echo "  config      Update configuration"
    echo "  backup      Create backup of data and configuration"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build && $0 start    # Build and start services"
    echo "  $0 logs ai-drug-discovery  # Show logs for main service"
    echo "  $0 dev                   # Start in development mode"
    echo "  $0 prod                  # Start in production mode"
    echo ""
}

# Main execution
main() {
    case "${1:-}" in
        build)
            check_docker
            build_image
            ;;
        start)
            check_docker
            start_services
            ;;
        stop)
            check_docker
            stop_services
            ;;
        restart)
            check_docker
            restart_services
            ;;
        status)
            check_docker
            show_status
            ;;
        logs)
            check_docker
            show_logs "${2:-}"
            ;;
        dev)
            check_docker
            run_dev
            ;;
        prod)
            check_docker
            run_prod
            ;;
        shell)
            check_docker
            shell
            ;;
        cleanup)
            check_docker
            cleanup
            ;;
        config)
            check_docker
            update_config
            ;;
        backup)
            check_docker
            backup
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            print_error "No command specified"
            show_help
            exit 1
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Check if running as root (not recommended for development)
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root is not recommended for development."
fi

# Run main function with all arguments
main "$@"
