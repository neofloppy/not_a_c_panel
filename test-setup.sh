#!/bin/bash

# Test script for Not a cPanel setup
# This script tests if all components are working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

echo ""
echo "🧪 Not a cPanel - Setup Test"
echo "============================"
echo ""

# Test 1: Check if Docker is running
print_status "Checking Docker status..."
if docker info >/dev/null 2>&1; then
    print_success "Docker is running"
else
    print_error "Docker is not running or not accessible"
    exit 1
fi

# Test 2: Check if containers are running
print_status "Checking container status..."
running_containers=$(docker-compose ps -q | wc -l)
if [ "$running_containers" -eq 10 ]; then
    print_success "All 10 containers are running"
else
    print_error "Expected 10 containers, found $running_containers"
    docker-compose ps
fi

# Test 3: Check if containers are responding
print_status "Testing container connectivity..."
failed_tests=0

for i in {1..10}; do
    port=$((8000 + i))
    if curl -s -f "http://localhost:$port/health" >/dev/null; then
        print_success "Container on port $port is responding"
    else
        print_error "Container on port $port is not responding"
        ((failed_tests++))
    fi
done

# Test 4: Check if Python dependencies are installed
print_status "Checking Python dependencies..."
if python3 -c "import flask, flask_cors" 2>/dev/null; then
    print_success "Python dependencies are installed"
else
    print_error "Python dependencies are missing"
    ((failed_tests++))
fi

# Test 5: Check if server.py can be imported
print_status "Testing server.py..."
if python3 -c "import sys; sys.path.append('.'); import server" 2>/dev/null; then
    print_success "server.py is valid"
else
    print_error "server.py has issues"
    ((failed_tests++))
fi

# Test 6: Check directory structure
print_status "Checking directory structure..."
required_dirs=("nginx-configs" "web-content")
for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        print_success "Directory $dir exists"
    else
        print_error "Directory $dir is missing"
        ((failed_tests++))
    fi
done

# Test 7: Check configuration files
print_status "Checking configuration files..."
containers=("web-01" "web-02" "web-03" "web-04" "web-05" "api-01" "api-02" "lb-01" "static-01" "proxy-01")
for container in "${containers[@]}"; do
    if [ -f "nginx-configs/$container/default.conf" ]; then
        print_success "Config for $container exists"
    else
        print_error "Config for $container is missing"
        ((failed_tests++))
    fi
done

echo ""
echo "📊 Test Summary"
echo "==============="

if [ $failed_tests -eq 0 ]; then
    print_success "All tests passed! ✅"
    echo ""
    echo "🎉 Your Not a cPanel setup is working correctly!"
    echo ""
    echo "Next steps:"
    echo "1. Start the control panel: python3 server.py"
    echo "2. Access it at: http://localhost:5000"
    echo "3. Login with admin / docker123!"
else
    print_error "$failed_tests test(s) failed ❌"
    echo ""
    echo "Please check the errors above and run the setup script again."
    exit 1
fi