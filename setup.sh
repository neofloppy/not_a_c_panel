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
        <p><a href="http://localhost:5000" target="_blank">🔗 Access Control Panel</a></p>
    </div>
</body>
</html>
EOF
done

print_success "Nginx configurations created"

# Install Python dependencies
print_status "Installing Python dependencies..."
pip3 install -r requirements.txt

print_success "Python dependencies installed"

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

# Check container status
print_status "Checking container status..."
docker-compose ps

# Test container connectivity
print_status "Testing container connectivity..."
failed_containers=()

for i in {1..10}; do
    port=$((8000 + i))
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/health | grep -q "200"; then
        print_success "Container on port $port is responding"
    else
        print_warning "Container on port $port is not responding"
        failed_containers+=($port)
    fi
done

if [ ${#failed_containers[@]} -eq 0 ]; then
    print_success "All containers are running and responding!"
else
    print_warning "Some containers are not responding: ${failed_containers[*]}"
fi

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Next steps:"
echo "1. Start the control panel: python3 server.py"
echo "2. Access the control panel at: http://localhost:5000"
echo "3. Login with:"
echo "   - Username: admin"
echo "   - Password: docker123!"
echo ""
echo "Container URLs:"
for i in {1..10}; do
    port=$((8000 + i))
    echo "   - Container $i: http://localhost:$port"
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