#!/bin/sh

# Not a cPanel - Universal Installer (POSIX sh compatible)
# This script installs all dependencies, sets up the environment, and configures the app.

set -e

echo "=============================================="
echo "  Not a cPanel - Universal Installer"
echo "=============================================="

print_status() { echo "[INFO] $1"; }
print_success() { echo "[SUCCESS] $1"; }
print_warning() { echo "[WARNING] $1"; }
print_error() { echo "[ERROR] $1"; }

echo ""
print_status "Please enter the following configuration details:"

while [ -z "$SERVER_IP" ]
do
    printf "Server IP address: "
    read SERVER_IP
    if [ -z "$SERVER_IP" ]; then print_error "Server IP is required."; fi
done

while [ -z "$ADMIN_USER" ]
do
    printf "Admin username: "
    read ADMIN_USER
    if [ -z "$ADMIN_USER" ]; then print_error "Admin username is required."; fi
done

while [ -z "$ADMIN_PASS" ]
do
    printf "Admin password: "
    stty -echo
    read ADMIN_PASS
    stty echo
    echo ""
    if [ -z "$ADMIN_PASS" ]; then print_error "Admin password is required."; fi
done

echo ""
print_status "PostgreSQL Database Settings (all required):"

while [ -z "$PG_HOST" ]
do
    printf "PostgreSQL host: "
    read PG_HOST
    if [ -z "$PG_HOST" ]; then print_error "PostgreSQL host is required."; fi
done

while [ -z "$PG_PORT" ]
do
    printf "PostgreSQL port: "
    read PG_PORT
    if [ -z "$PG_PORT" ]; then print_error "PostgreSQL port is required."; fi
done

while [ -z "$PG_USER" ]
do
    printf "PostgreSQL user: "
    read PG_USER
    if [ -z "$PG_USER" ]; then print_error "PostgreSQL user is required."; fi
done

while [ -z "$PG_PASS" ]
do
    printf "PostgreSQL password: "
    stty -echo
    read PG_PASS
    stty echo
    echo ""
    if [ -z "$PG_PASS" ]; then print_error "PostgreSQL password is required."; fi
done

while [ -z "$PG_DB" ]
do
    printf "PostgreSQL database name: "
    read PG_DB
    if [ -z "$PG_DB" ]; then print_error "PostgreSQL database name is required."; fi
done

print_success "Configuration collected."

print_status "Updating package lists and installing dependencies..."
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y python3 python3-venv python3-pip git curl docker.io docker-compose
elif command -v yum >/dev/null 2>&1; then
    sudo yum install -y python3 python3-venv python3-pip git curl docker docker-compose
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y python3 python3-venv python3-pip git curl docker docker-compose
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm python python-venv python-pip git curl docker docker-compose
elif command -v zypper >/dev/null 2>&1; then
    sudo zypper install -y python3 python3-venv python3-pip git curl docker docker-compose
else
    print_error "Unsupported package manager. Please install dependencies manually."
    exit 1
fi

print_success "System dependencies installed."

if ! pgrep -x "dockerd" >/dev/null 2>&1; then
    print_status "Starting Docker service..."
    sudo systemctl start docker || sudo service docker start
fi

if ! groups "$USER" | grep -q '\bdocker\b'; then
    print_status "Adding $USER to docker group..."
    sudo usermod -aG docker "$USER"
    print_warning "You may need to log out and log back in for docker group changes to take effect."
fi

print_status "Setting up Python virtual environment..."
python3 -m venv venv
. venv/bin/activate

print_status "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

print_success "Python environment ready."

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

echo ""
print_status "To start the backend server, run:"
echo "source venv/bin/activate && python server.py"
print_status "To access the frontend, open index.html in your browser."
print_status "If you need to change configuration, edit the .env file and restart the backend."

print_success "Installation complete!"