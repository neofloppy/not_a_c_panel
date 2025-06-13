#!/bin/bash

# Not a cPanel - Complete Uninstall Script
# This script removes all components and data

echo "🗑️  Not a cPanel - Complete Uninstall"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
print_warning "This will completely remove Not a cPanel and all its data!"
print_warning "This includes:"
echo "  - All Docker containers and images"
echo "  - All configuration files"
echo "  - All web content"
echo "  - The entire installation directory"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [ "$confirm" != "yes" ]; then
    print_status "Uninstall cancelled"
    exit 0
fi

echo ""
print_status "Starting complete uninstall..."

# Stop and remove Docker containers
print_status "Stopping and removing Docker containers..."
if [ -f "docker-compose.yml" ]; then
    docker-compose down --volumes --remove-orphans 2>/dev/null || true
    print_success "Docker containers stopped and removed"
else
    print_warning "docker-compose.yml not found, manually removing containers..."
    # Remove containers by name pattern
    docker stop $(docker ps -q --filter "name=web-" --filter "name=api-" --filter "name=lb-" --filter "name=static-" --filter "name=proxy-") 2>/dev/null || true
    docker rm $(docker ps -aq --filter "name=web-" --filter "name=api-" --filter "name=lb-" --filter "name=static-" --filter "name=proxy-") 2>/dev/null || true
fi

# Remove Docker images
print_status "Removing Docker images..."
docker rmi nginx:alpine 2>/dev/null || true
print_success "Docker images removed"

# Remove Docker networks
print_status "Removing Docker networks..."
docker network rm not_a_c_panel_nginx-network 2>/dev/null || true
docker network prune -f 2>/dev/null || true
print_success "Docker networks cleaned"

# Remove Python virtual environment if it exists
if [ -d "venv" ]; then
    print_status "Removing Python virtual environment..."
    rm -rf venv
    print_success "Virtual environment removed"
fi

# Remove system-installed Python packages (optional)
print_status "Checking for system-installed Python packages..."
if dpkg -l | grep -q python3-flask; then
    read -p "Remove system-installed Flask packages? (y/n): " remove_flask
    if [ "$remove_flask" = "y" ]; then
        sudo apt-get remove -y python3-flask python3-flask-cors 2>/dev/null || true
        sudo apt-get autoremove -y 2>/dev/null || true
        print_success "System Python packages removed"
    fi
fi

# Go to parent directory
cd ..

# Remove the entire installation directory
INSTALL_DIR="not_a_c_panel"
if [ -d "$INSTALL_DIR" ]; then
    print_status "Removing installation directory: $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
    print_success "Installation directory removed"
fi

# Clean up any remaining Docker volumes
print_status "Cleaning up Docker volumes..."
docker volume prune -f 2>/dev/null || true

# Clean up Docker system
print_status "Cleaning up Docker system..."
docker system prune -f 2>/dev/null || true

echo ""
print_success "🎉 Complete uninstall finished!"
echo ""
print_status "What was removed:"
echo "  ✅ All Docker containers (web-01 through proxy-01)"
echo "  ✅ All Docker images (nginx:alpine)"
echo "  ✅ All Docker networks and volumes"
echo "  ✅ Installation directory and all files"
echo "  ✅ Configuration files and web content"
echo "  ✅ Python virtual environment (if existed)"
echo ""
print_status "Your system is now clean and ready for a fresh installation"
echo ""
print_status "To reinstall, run:"
echo "  curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/install.sh | bash"
echo ""