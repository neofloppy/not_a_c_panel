#!/bin/bash

# Quick fix for externally managed Python environment error
# Run this if you got the "externally-managed-environment" error

set -e

echo "🔧 Python Environment Fix"
echo "========================="

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

print_status "Fixing Python environment issue..."

# Method 1: Install via system packages
print_status "Installing Python packages via system package manager..."
sudo apt-get update
sudo apt-get install -y python3-flask python3-flask-cors

print_success "System packages installed"

# Collect configuration if not already done
if [ ! -f "config.py" ]; then
    print_status "Configuration file not found. Setting up configuration..."
    
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

    # Update template files
    if [ -f "update-templates.py" ]; then
        print_status "Updating template files..."
        python3 update-templates.py
        print_success "Template files updated"
    fi
fi

# Test if Python dependencies work
print_status "Testing Python dependencies..."
if python3 -c "import flask, flask_cors" 2>/dev/null; then
    print_success "Python dependencies are working correctly"
else
    print_error "Python dependencies still not working. Trying alternative method..."
    
    # Alternative: Create virtual environment
    print_status "Creating virtual environment as fallback..."
    python3 -m venv venv
    source venv/bin/activate
    pip install flask flask-cors
    
    # Create startup script for virtual environment
    cat > start-server.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python server.py
EOF
    chmod +x start-server.sh
    
    print_success "Virtual environment created. Use './start-server.sh' to start the server"
fi

print_success "Python environment fix complete!"

echo ""
echo "🎉 Ready to start!"
echo ""
echo "To start the control panel:"
if [ -f "start-server.sh" ]; then
    echo "  ./start-server.sh"
else
    echo "  python3 server.py"
fi
echo ""
echo "Then visit: http://$(grep SERVER_IP config.py 2>/dev/null | cut -d'"' -f2 || echo 'localhost'):5000"
echo ""