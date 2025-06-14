#!/bin/bash

# Not a cPanel - Docker Setup Script (Virtual Environment Version)
# This script sets up the Docker environment using Python virtual environment

set -e

echo "🐳 Not a cPanel - Docker Setup (Virtual Environment)"
echo "===================================================="

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

# Install required system packages
print_status "Installing required system packages..."
sudo apt-get update
sudo apt-get install -y python3-full python3-venv curl git
# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    print_status "You can install Docker using: curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
    exit 1
fi

# Check if Docker Compose (v1 or v2) is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose (v2 or v1) first."
    print_status "You can install Docker Compose v2 (recommended) using: sudo apt-get install docker-compose-plugin"
    print_status "Or install Docker Compose v1 using: sudo curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
fi

# Create virtual environment
print_status "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

print_success "Virtual environment created and activated"

# Install Python dependencies in virtual environment
print_status "Installing Python dependencies in virtual environment..."
pip install flask flask-cors

print_success "Python dependencies installed"

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
python update-templates.py

print_success "Template files updated"

# Create startup script
print_status "Creating startup script..."
cat > start-server.sh << 'EOF'
#!/bin/bash
# Start Not a cPanel with virtual environment

cd "$(dirname "$0")"
source venv/bin/activate
python server.py
EOF

chmod +x start-server.sh

print_success "Startup script created"

print_status "Creating directory structure..."

# Create nginx configuration directories
mkdir -p nginx-configs/{web-01,web-02,web-03,web-04,web-05,api-01,api-02,lb-01,static-01,proxy-01}
mkdir -p web-content/{web-01,web-02,web-03,web-04,web-05,api-01,api-02,lb-01,static-01,proxy-01}

print_success "Directory structure created"

# Create default nginx configurations
print_status "Creating default Nginx configurations..."

containers=("web-01" "web-02" "web-03" "web-04" "web-05" "api-01" "api-02" "lb-01" "static-01" "proxy-01")

for container in "${containers[@]}"; do
    cat > nginx-configs/$container/default.conf << EOF
server {
    listen 80;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

    # Create a simple index.html for each container
    cat > web-content/$container/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>$container - Not a cPanel</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .status { color: #28a745; font-weight: bold; }
        .info { background: #e9ecef; padding: 15px; border-radius: 4px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳 Container: $container</h1>
        <p class="status">✅ Container is running successfully!</p>
        <div class="info">
            <h3>Container Information:</h3>
            <ul>
                <li><strong>Container Name:</strong> $container</li>
                <li><strong>Service Type:</strong> Nginx Web Server</li>
                <li><strong>Status:</strong> Active</li>
                <li><strong>Managed by:</strong> Not a cPanel</li>
            </ul>
        </div>
        <p>This container is managed by the <strong>Not a cPanel</strong> control panel.</p>
        <p><a href="http://$SERVER_IP:5000" target="_blank">🔗 Access Control Panel</a></p>
    </div>
</body>
</html>
EOF
done

print_success "Nginx configurations created"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    print_warning "Please log out and log back in, or run 'newgrp docker' to apply group changes"
    print_status "Continuing with setup..."
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_status "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Pull Docker images
print_status "Pulling Docker images..."
docker-compose pull

print_success "Docker images pulled"

# Start Docker containers
print_status "Starting Docker containers..."
docker-compose up -d

print_success "Docker containers started"

# Wait for containers to be ready
print_status "Waiting for containers to be ready..."
sleep 10

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Configuration:"
echo "- Server IP: $SERVER_IP"
echo "- Username: $USERNAME"
echo "- Control Panel: http://$SERVER_IP:5000"
echo ""
echo "To start the control panel:"
echo "  ./start-server.sh"
echo ""
echo "Or manually:"
echo "  source venv/bin/activate"
echo "  python server.py"
echo ""
echo "Login credentials:"
echo "- Username: admin"
echo "- Password: $ADMIN_PASSWORD"
echo ""

# Ask if user wants to start now
echo "Would you like to start the control panel now? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    print_status "Starting control panel..."
    ./start-server.sh
fi