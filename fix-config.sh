#!/bin/bash

# Fix config.py syntax error and reconfigure

echo "🔧 Fixing Configuration File"
echo "============================"

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

# Check current config file
if [ -f "config.py" ]; then
    print_status "Current config.py content:"
    echo "----------------------------------------"
    cat config.py
    echo "----------------------------------------"
    echo ""
    
    # Test the syntax
    if python3 -c "exec(open('config.py').read())" 2>/dev/null; then
        print_success "Config file syntax is valid"
    else
        print_error "Config file has syntax errors"
        print_status "Backing up current config..."
        cp config.py config.py.backup
    fi
fi

# Reconfigure
print_status "Let's reconfigure your settings..."
echo ""

# Get server IP
print_status "Detecting server IP address..."
DEFAULT_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "4.221.197.153")
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

# Create new configuration file
print_status "Creating new configuration file..."
cat > config.py << EOF
# Not a cPanel Configuration
# Generated during installation

SERVER_IP = "$SERVER_IP"
USERNAME = "$USERNAME"
ADMIN_PASSWORD = "$ADMIN_PASSWORD"
EOF

print_success "Configuration file created"

# Test the new config
print_status "Testing new configuration..."
if python3 -c "exec(open('config.py').read()); print(f'Server: {SERVER_IP}, User: {USERNAME}')" 2>/dev/null; then
    print_success "New configuration is valid"
else
    print_error "New configuration still has issues"
    exit 1
fi

# Update template files
if [ -f "update-templates.py" ]; then
    print_status "Updating template files with new configuration..."
    python3 update-templates.py
    print_success "Template files updated"
fi

echo ""
print_success "Configuration fix complete!"
echo ""
echo "Your settings:"
echo "- Server IP: $SERVER_IP"
echo "- Username: $USERNAME"
echo "- Control Panel: http://$SERVER_IP:5000"
echo ""
echo "To start the server:"
echo "  ./start-server.sh"
echo ""
echo "Or manually:"
echo "  python3 server.py"
echo ""