#!/bin/bash

# Not a cPanel - Docker Setup Script
# This script sets up the Docker environment for the control panel

set -e

echo "🐳 Not a cPanel - Docker Setup"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons"
   exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    print_status "You can install Docker using: curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    print_status "You can install Docker Compose using: sudo curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
fi

# Check if user is in docker group
if ! groups $USER | grep &>/dev/null '\bdocker\b'; then
    print_warning "User $USER is not in the docker group. Adding user to docker group..."
    sudo usermod -aG docker $USER
    print_warning "Please log out and log back in, or run 'newgrp docker' to apply group changes"
fi

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

# Check if pip3 is installed and install if missing
if ! command -v pip3 &> /dev/null; then
    print_warning "pip3 is not installed. Installing pip3..."
    
    # Detect OS and install pip3 accordingly
    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        print_status "Installing pip3 using apt-get..."
        sudo apt-get update
        sudo apt-get install -y python3-pip
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL/Fedora
        print_status "Installing pip3 using yum..."
        sudo yum install -y python3-pip
    elif command -v dnf &> /dev/null; then
        # Fedora (newer versions)
        print_status "Installing pip3 using dnf..."
        sudo dnf install -y python3-pip
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        print_status "Installing pip3 using pacman..."
        sudo pacman -S --noconfirm python-pip
    elif command -v zypper &> /dev/null; then
        # openSUSE
        print_status "Installing pip3 using zypper..."
        sudo zypper install -y python3-pip
    else
        print_error "Could not detect package manager. Please install pip3 manually:"
        print_status "Ubuntu/Debian: sudo apt-get install python3-pip"
        print_status "CentOS/RHEL: sudo yum install python3-pip"
        print_status "Fedora: sudo dnf install python3-pip"
        print_status "Arch: sudo pacman -S python-pip"
        exit 1
    fi
    
    # Verify installation
    if command -v pip3 &> /dev/null; then
        print_success "pip3 installed successfully"
    else
        print_error "Failed to install pip3. Please install it manually."
        exit 1
    fi
fi

# Collect user configuration
echo ""
print_status "Configuration Setup"
echo "==================="
echo ""

# Get server IP
print_status "Detecting server IP address..."
DEFAULT_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "localhost")
echo "Detected IP: $DEFAULT_IP"
echo ""
read -p "Enter your server IP address (or press Enter for $DEFAULT_IP): " SERVER_IP
SERVER_IP=${SERVER_IP:-$DEFAULT_IP}

# Get username
DEFAULT_USER=$(whoami)
echo ""
read -p "Enter your username (or press Enter for $DEFAULT_USER): " USERNAME
USERNAME=${USERNAME:-$DEFAULT_USER}

# Get admin password
echo ""
read -s -p "Enter admin password for the control panel (or press Enter for 'docker123!'): " ADMIN_PASSWORD
echo ""
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"docker123!"}

print_success "Configuration collected:"
print_status "Server IP: $SERVER_IP"
print_status "Username: $USERNAME"
print_status "Admin Password: [HIDDEN]"
echo ""

# Create configuration file
print_status "Creating configuration file..."
cat > config.py << EOF
# Not a cPanel Configuration
# Generated during installation

SERVER_IP = "$SERVER_IP"
USERNAME = "$USERNAME"
ADMIN_PASSWORD = "$ADMIN_PASSWORD"
EOF

print_success "Configuration file created"

# Update template files with configuration
print_status "Updating template files with your configuration..."
python3 update-templates.py

print_success "Template files updated"

print_status "Creating base directory structure..."

# Create base directories for dynamic container creation
mkdir -p nginx-configs
mkdir -p web-content

print_success "Base directory structure created"

# Install Python dependencies
print_status "Installing Python dependencies..."

# Check if we're in an externally managed environment (Ubuntu 23.04+)
if pip3 install --dry-run flask 2>&1 | grep -q "externally-managed-environment"; then
    print_warning "Detected externally managed Python environment"
    print_status "Installing dependencies using system package manager..."
    
    # Install Python packages via apt
    sudo apt-get update
    sudo apt-get install -y python3-flask python3-flask-cors
    
    print_success "Python dependencies installed via apt"
else
    # Traditional pip installation
    pip3 install -r requirements.txt
    print_success "Python dependencies installed via pip"
fi

# Install PostgreSQL
print_status "Installing PostgreSQL..."
sudo apt-get install -y postgresql postgresql-contrib python3-psycopg2

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user for Not a cPanel
print_status "Setting up PostgreSQL database..."
sudo -u postgres psql << EOF
CREATE DATABASE notacpanel;
CREATE USER notacpanel WITH ENCRYPTED PASSWORD 'notacpanel123';
GRANT ALL PRIVILEGES ON DATABASE notacpanel TO notacpanel;
\q
EOF

print_success "PostgreSQL installed and configured"

# Pull common Docker images
print_status "Pulling common Docker images..."
docker pull nginx:alpine
docker pull postgres:alpine
docker pull redis:alpine
docker pull node:alpine

print_success "Common Docker images pulled"

# Create systemd service
print_status "Creating systemd service..."
sudo tee /etc/systemd/system/not-a-cpanel.service > /dev/null << EOF
[Unit]
Description=Not a cPanel - Docker Container Management
After=network.target docker.service postgresql.service
Requires=docker.service postgresql.service

[Service]
Type=simple
User=$USERNAME
Group=docker
WorkingDirectory=$HOME/not_a_c_panel
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStart=/usr/bin/python3 server.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable not-a-cpanel

print_success "Systemd service created and enabled"

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Configuration:"
echo "- Server IP: $SERVER_IP"
echo "- Username: $USERNAME"
echo "- Control Panel: http://$SERVER_IP:5000"
echo ""
echo "Next steps:"
echo "1. Start the control panel: python3 server.py"
echo "2. Access the control panel at: http://$SERVER_IP:5000"
echo "3. Login with:"
echo "   - Username: admin"
echo "   - Password: $ADMIN_PASSWORD"
echo ""
echo "Container URLs:"
for i in {1..10}; do
    port=$((8000 + i))
    echo "   - Container $i: http://$SERVER_IP:$port"
done
echo ""
echo "📚 For more information, check the README.md file"
echo ""

# Check if server.py exists and offer to start it
if [ -f "server.py" ]; then
    echo "Would you like to start the control panel now? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        print_status "Starting control panel..."
        python3 server.py
    fi
fi