#!/bin/bash

# Docker deployment test script
# This script tests the Docker deployment to ensure everything works correctly

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_TIMEOUT=60
CONTAINER_NAME="ai-drug-discovery-agent"

print_status() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[DOCKER-TEST]${NC} $1"
}

# Function to test HTTP endpoint
test_endpoint() {
    local url=$1
    local name=$2
    local expected_status=${3:-200}
    
    print_status "Testing $name at $url"
    
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" || echo "000")
    
    if [ "$response_code" = "$expected_status" ]; then
        echo -e "  ${GREEN}✓${NC} $name responded with status $response_code"
        return 0
    else
        echo -e "  ${RED}✗${NC} $name responded with status $response_code (expected $expected_status)"
        return 1
    fi
}

# Function to test API functionality
test_api_functionality() {
    local api_base="http://localhost:8088"
    local fake_api_base="http://localhost:8288"
    
    print_header "Testing API functionality..."
    
    # Test MCP Gateway endpoints
    local failed=0
    
    # Test root endpoint
    if ! test_endpoint "$api_base" "MCP Gateway Root" 200; then
        failed=$((failed + 1))
    fi
    
    # Test health endpoint
    if ! test_endpoint "$api_base/health" "MCP Gateway Health" 200; then
        failed=$((failed + 1))
    fi
    
    # Test servers list endpoint
    if ! test_endpoint "$api_base/servers" "MCP Servers List" 200; then
        failed=$((failed + 1))
    fi
    
    # Test Fake API endpoints
    if ! test_endpoint "$fake_api_base" "Fake API Root" 200; then
        failed=$((failed + 1))
    fi
    
    if ! test_endpoint "$fake_api_base/api/targets/list" "Fake API Targets" 200; then
        failed=$((failed + 1))
    fi
    
    # Test Web Interface
    if ! test_endpoint "http://localhost:8080" "Web Interface" 200; then
        failed=$((failed + 1))
    fi
    
    return $failed
}

# Function to test container functionality
test_container() {
    print_header "Testing container functionality..."
    
    # Check if container is running
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "Container $CONTAINER_NAME is not running"
        return 1
    fi
    
    print_status "Container is running"
    
    # Check container logs for errors
    local error_count=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -i error | wc -l)
    if [ "$error_count" -gt 0 ]; then
        print_warning "Found $error_count error messages in container logs"
        echo "Recent errors:"
        docker logs "$CONTAINER_NAME" 2>&1 | grep -i error | tail -5
    else
        print_status "No errors found in container logs"
    fi
    
    # Test container health
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "no-healthcheck")
    if [ "$health_status" = "healthy" ]; then
        print_status "Container health check: healthy"
    elif [ "$health_status" = "no-healthcheck" ]; then
        print_warning "No health check configured for container"
    else
        print_error "Container health check: $health_status"
        return 1
    fi
    
    return 0
}

# Function to run performance tests
test_performance() {
    print_header "Testing basic performance..."
    
    local api_url="http://localhost:8088/health"
    local total_requests=10
    local successful=0
    local total_time=0
    
    print_status "Sending $total_requests requests to health endpoint..."
    
    for i in $(seq 1 $total_requests); do
        local start_time=$(date +%s.%N)
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$api_url" || echo "000")
        local end_time=$(date +%s.%N)
        
        if [ "$response_code" = "200" ]; then
            successful=$((successful + 1))
            local request_time=$(echo "$end_time - $start_time" | bc -l)
            total_time=$(echo "$total_time + $request_time" | bc -l)
        fi
    done
    
    if [ $successful -gt 0 ]; then
        local avg_time=$(echo "scale=3; $total_time / $successful" | bc -l)
        print_status "Performance test: $successful/$total_requests successful requests"
        print_status "Average response time: ${avg_time}s"
    else
        print_error "Performance test failed: no successful requests"
        return 1
    fi
    
    return 0
}

# Function to test resource usage
test_resources() {
    print_header "Checking resource usage..."
    
    # Get container resource usage
    local stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep "$CONTAINER_NAME" || echo "")
    
    if [ -n "$stats" ]; then
        print_status "Container resource usage:"
        echo "  $stats"
    else
        print_warning "Could not retrieve resource usage statistics"
    fi
    
    # Check disk usage
    local disk_usage=$(docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}")
    print_status "Docker disk usage:"
    echo "$disk_usage"
    
    return 0
}

# Function to run all tests
run_all_tests() {
    local failed_tests=0
    
    print_header "Starting Docker deployment tests..."
    echo ""
    
    # Wait for services to be ready
    print_status "Waiting for services to be ready..."
    if ! ./health-check.sh wait; then
        print_error "Services failed to start properly"
        return 1
    fi
    
    echo ""
    
    # Run container tests
    if ! test_container; then
        failed_tests=$((failed_tests + 1))
    fi
    
    echo ""
    
    # Run API functionality tests
    local api_failures=0
    if ! api_failures=$(test_api_functionality); then
        failed_tests=$((failed_tests + api_failures))
    fi
    
    echo ""
    
    # Run performance tests
    if command -v bc >/dev/null 2>&1; then
        if ! test_performance; then
            failed_tests=$((failed_tests + 1))
        fi
    else
        print_warning "bc command not found, skipping performance tests"
    fi
    
    echo ""
    
    # Check resource usage
    test_resources
    
    echo ""
    
    # Summary
    if [ $failed_tests -eq 0 ]; then
        print_header "🎉 All tests passed!"
        echo ""
        print_status "Docker deployment is working correctly"
        print_status "Access the application at:"
        echo "  • Web Interface: http://localhost:8080"
        echo "  • MCP Gateway:   http://localhost:8088"
        echo "  • Fake API:      http://localhost:8288"
        return 0
    else
        print_header "❌ $failed_tests test(s) failed"
        echo ""
        print_error "Docker deployment has issues that need to be addressed"
        return 1
    fi
}

# Function to clean up test environment
cleanup_test() {
    print_header "Cleaning up test environment..."
    
    # Stop and remove test containers
    docker-compose down -v --remove-orphans 2>/dev/null || true
    
    print_status "Test cleanup completed"
}

# Function to show help
show_help() {
    echo "Docker Deployment Test Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  test        Run all tests (default)"
    echo "  api         Test API functionality only"
    echo "  container   Test container functionality only"
    echo "  performance Test performance only"
    echo "  resources   Check resource usage only"
    echo "  cleanup     Clean up test environment"
    echo "  help        Show this help message"
    echo ""
}

# Main execution
main() {
    case "${1:-test}" in
        test)
            run_all_tests
            ;;
        api)
            test_api_functionality
            ;;
        container)
            test_container
            ;;
        performance)
            if command -v bc >/dev/null 2>&1; then
                test_performance
            else
                print_error "bc command is required for performance tests"
                exit 1
            fi
            ;;
        resources)
            test_resources
            ;;
        cleanup)
            cleanup_test
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

# Change to project directory
cd "$PROJECT_DIR"

# Run main function
main "$@"
