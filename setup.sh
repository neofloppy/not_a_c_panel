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

# Check if Docker Compose (v1 or v2) is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose (v2 or v1) first."
    print_status "You can install Docker Compose v2 (recommended) using: sudo apt-get install docker-compose-plugin"
    print_status "Or install Docker Compose v1 using: sudo curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose"
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
# Get database password
echo ""
read -s -p "Enter database password for PostgreSQL (or press Enter for 'notacpanel123'): " DB_PASSWORD
echo ""
DB_PASSWORD=${DB_PASSWORD:-"notacpanel123"}

print_success "Configuration collected:"
print_status "Server IP: $SERVER_IP"
print_status "Username: $USERNAME"
print_status "Admin Password: [HIDDEN]"
print_status "Database Password: [HIDDEN]"
print_status "FTP Passive Ports: $FTP_PASV_MIN-$FTP_PASV_MAX"
if [[ -n "$ADMIN_EMAIL" ]]; then
    print_status "Admin Email: $ADMIN_EMAIL"
fi
echo ""

# Create configuration file
print_status "Creating configuration file..."
cat > config.py << EOF
# Not a cPanel Configuration
# Generated during installation on $(date)

# Server Configuration
SERVER_IP = "$SERVER_IP"
USERNAME = "$USERNAME"
ADMIN_PASSWORD = "$ADMIN_PASSWORD"

# Database Configuration
DB_PASSWORD = "$DB_PASSWORD"

# FTP Configuration
FTP_PASV_MIN = $FTP_PASV_MIN
FTP_PASV_MAX = $FTP_PASV_MAX

# Optional Settings
ADMIN_EMAIL = "$ADMIN_EMAIL"

# Installation Info
INSTALL_DATE = "$(date)"
INSTALL_VERSION = "1.0.0"
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
print_status "Installing PostgreSQL server..."
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib python3-psycopg2

# Start and enable PostgreSQL service
print_status "Starting PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Wait for PostgreSQL to be ready
sleep 3

# Check if PostgreSQL is running
if sudo systemctl is-active --quiet postgresql; then
    print_success "PostgreSQL service is running"
else
    print_error "PostgreSQL service failed to start"
    exit 1
fi

# Create database and user for Not a cPanel
print_status "Setting up PostgreSQL database and user..."

# Create the database and user
sudo -u postgres psql << EOF
-- Drop existing database and user if they exist (for clean reinstall)
DROP DATABASE IF EXISTS notacpanel;
DROP USER IF EXISTS notacpanel;

-- Create new database and user
CREATE DATABASE notacpanel;
CREATE USER notacpanel WITH ENCRYPTED PASSWORD '$DB_PASSWORD';

-- Grant all privileges
GRANT ALL PRIVILEGES ON DATABASE notacpanel TO notacpanel;

-- Grant additional privileges for schema creation
ALTER USER notacpanel CREATEDB;

-- Connect to the database and grant schema privileges
\c notacpanel;
GRANT ALL ON SCHEMA public TO notacpanel;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO notacpanel;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO notacpanel;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO notacpanel;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO notacpanel;

\q
EOF

# Test database connection
print_status "Testing PostgreSQL connection..."
if PGPASSWORD=$DB_PASSWORD psql -h localhost -U notacpanel -d notacpanel -c "SELECT version();" > /dev/null 2>&1; then
    print_success "PostgreSQL database connection successful"
else
    print_error "PostgreSQL database connection failed"
    exit 1
fi

# Configure PostgreSQL for local connections
print_status "Configuring PostgreSQL for local connections..."

# Backup original pg_hba.conf
sudo cp /etc/postgresql/*/main/pg_hba.conf /etc/postgresql/*/main/pg_hba.conf.backup

# Add local connection rule for notacpanel user
sudo sed -i '/^local.*all.*postgres.*peer/a local   notacpanel      notacpanel                              md5' /etc/postgresql/*/main/pg_hba.conf

# Reload PostgreSQL configuration
sudo systemctl reload postgresql

print_success "PostgreSQL installed and configured successfully"
print_status "Database: notacpanel"
print_status "User: notacpanel"
print_status "Password: notacpanel123"
print_status "Connection: localhost:5432"

# Install and configure FTP server (vsftpd)
print_status "Installing FTP server (vsftpd)..."
sudo apt-get install -y vsftpd

# Configure vsftpd for container-based FTP access
print_status "Configuring FTP server..."

# Backup original config
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.backup

# Create new vsftpd configuration
sudo tee /etc/vsftpd.conf > /dev/null << 'EOF'
# Basic FTP settings
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO

# User restrictions
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO

# Passive mode configuration
pasv_enable=YES
pasv_min_port=$FTP_PASV_MIN
pasv_max_port=$FTP_PASV_MAX
pasv_address=$SERVER_IP

# Logging
log_ftp_protocol=YES
xferlog_file=/var/log/vsftpd.log

# Allow users to access their container directories
allow_writeable_chroot=YES
EOF

# Create FTP user list file
sudo touch /etc/vsftpd.userlist

# Create base FTP directory structure
sudo mkdir -p /var/ftp/containers
sudo chown root:root /var/ftp/containers
sudo chmod 755 /var/ftp/containers

# Start and enable FTP service
sudo systemctl start vsftpd
sudo systemctl enable vsftpd

# Check if FTP service is running
if sudo systemctl is-active --quiet vsftpd; then
    print_success "FTP server installed and running"
else
    print_error "FTP server failed to start"
    exit 1
fi

print_success "FTP server configured successfully"
print_status "FTP Server: $SERVER_IP:21"
print_status "Passive ports: $FTP_PASV_MIN-$FTP_PASV_MAX"

# Pull common Docker images
print_status "Pulling common Docker images..."
docker pull nginx:alpine
docker pull node:alpine
docker pull php:apache
docker pull python:alpine
docker pull redis:alpine

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

# Make management scripts executable
print_status "Setting up management scripts..."
chmod +x manage-postgres.sh
chmod +x fix-config.sh
chmod +x fix-python-env.sh
chmod +x uninstall.sh

print_success "Management scripts ready"

echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Configuration:"
echo "- Server IP: $SERVER_IP"
echo "- Username: $USERNAME"
echo "- Control Panel: http://$SERVER_IP:5000"
echo "- PostgreSQL Database: notacpanel (user: notacpanel)"
echo "- FTP Server: $SERVER_IP:21 (passive: $FTP_PASV_MIN-$FTP_PASV_MAX)"
if [[ -n "$ADMIN_EMAIL" ]]; then
    echo "- Admin Email: $ADMIN_EMAIL"
fi
echo ""
echo "Service Management:"
echo "- Start service: sudo systemctl start not-a-cpanel"
echo "- Stop service: sudo systemctl stop not-a-cpanel"
echo "- Check status: sudo systemctl status not-a-cpanel"
echo "- View logs: sudo journalctl -u not-a-cpanel -f"
echo ""
echo "Access Information:"
echo "- Control Panel: http://$SERVER_IP:5000"
echo "- Username: admin"
echo "- Password: [as configured during installation]"
echo ""
echo "Database Access:"
echo "- Host: localhost:5432"
echo "- Database: notacpanel"
echo "- Username: notacpanel"
echo "- Password: [as configured during installation]"
echo ""
echo "Features:"
echo "- ✅ Starts with zero containers (clean slate)"
echo "- ✅ Create containers dynamically through web interface"
echo "- ✅ PostgreSQL database installed and configured (native, not containerized)"
echo "- ✅ FTP server installed and configured (native, not containerized)"
echo "- ✅ Runs as systemd service (auto-start on boot)"
echo "- ✅ Docker container management"
echo "- ✅ Nginx configuration editor"
echo ""
echo "Management Scripts:"
echo "- PostgreSQL: ./manage-postgres.sh [status|connect|backup|restore|info|test]"
echo "- Configuration: ./fix-config.sh"
echo "- Uninstall: ./uninstall.sh"
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