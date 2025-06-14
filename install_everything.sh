#!/bin/bash

# Not a cPanel - Universal Installer
# This script installs all dependencies, sets up the environment, and configures the app.

set -e

echo "=============================================="
echo "  Not a cPanel - Universal Installer"
echo "=============================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Prompt for configuration
echo ""
print_status "Please enter the following configuration details:"

read -p "Server IP address [default: auto-detect]: " SERVER_IP
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
    print_status "Auto-detected IP: $SERVER_IP"
fi

read -p "Admin username [default: admin]: " ADMIN_USER
ADMIN_USER=${ADMIN_USER:-admin}

read -s -p "Admin password [default: docker123!]: " ADMIN_PASS
echo ""
ADMIN_PASS=${ADMIN_PASS:-docker123!}

echo ""
print_status "PostgreSQL Database Settings:"
read -p "PostgreSQL host [default: localhost]: " PG_HOST
PG_HOST=${PG_HOST:-localhost}
read -p "PostgreSQL port [default: 5432]: " PG_PORT
PG_PORT=${PG_PORT:-5432}
read -p "PostgreSQL user [default: postgres]: " PG_USER
PG_USER=${PG_USER:-postgres}
read -s -p "PostgreSQL password [default: postgres]: " PG_PASS
echo ""
PG_PASS=${PG_PASS:-postgres}
read -p "PostgreSQL database name [default: notacpanel]: " PG_DB
PG_DB=${PG_DB:-notacpanel}

echo ""
print_success "Configuration collected."

# Install system dependencies
print_status "Updating package lists and installing dependencies..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y python3 python3-venv python3-pip git curl docker.io docker-compose
elif command -v yum &> /dev/null; then
    sudo yum install -y python3 python3-venv python3-pip git curl docker docker-compose
elif command -v dnf &> /dev/null; then
    sudo dnf install -y python3 python3-venv python3-pip git curl docker docker-compose
elif command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm python python-venv python-pip git curl docker docker-compose
elif command -v zypper &> /dev/null; then
    sudo zypper install -y python3 python3-venv python3-pip git curl docker docker-compose
else
    print_error "Unsupported package manager. Please install dependencies manually."
    exit 1
fi

print_success "System dependencies installed."

# Start Docker if not running
if ! pgrep -x "dockerd" > /dev/null; then
    print_status "Starting Docker service..."
    sudo systemctl start docker || sudo service docker start
fi

# Add user to docker group if not already
if ! groups $USER | grep -q '\bdocker\b'; then
    print_status "Adding $USER to docker group..."
    sudo usermod -aG docker $USER
    print_warning "You may need to log out and log back in for docker group changes to take effect."
fi

# Set up Python virtual environment
print_status "Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

print_status "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

print_success "Python environment ready."

# Write configuration to .env file
cat > .env <<EOF
SERVER_IP=$SERVER_IP
ADMIN_USER=$ADMIN_USER
ADMIN_PASS=$ADMIN_PASS
PG_HOST=$PG_HOST
PG_PORT=$PG_PORT
PG_USER=$PG_USER
PG_PASS=$PG_PASS
PG_DB=$PG_DB
EOF

print_success "Configuration saved to .env"

# Provide instructions to start the backend
echo ""
print_status "To start the backend server, run:"
echo "source venv/bin/activate && python server.py"
print_status "To access the frontend, open index.html in your browser."
print_status "If you need to change configuration, edit the .env file and restart the backend."

print_success "Installation complete!"