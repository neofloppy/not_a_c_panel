#!/bin/bash

cat <<'EOF'
███╗   ██╗███████╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ██╗   ██╗
████╗  ██║██╔════╝██╔═══██╗██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝
██╔██╗ ██║█████╗  ██║   ██║█████╗  ██║     ██║   ██║██████╔╝██████╔╝ ╚████╔╝ 
██║╚██╗██║██╔══╝  ██║   ██║██╔══╝  ██║     ██║   ██║██╔═══╝ ██╔═══╝   ╚██╔╝  
██║ ╚████║███████╗╚██████╔╝██║     ███████╗╚██████╔╝██║     ██║        ██║   
╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝     ╚═╝        ╚═╝   
⠀⠀⠀⠀⢀⡴⠶⣶⣶⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⣰⠋⠀⢸⣿⣿⠿⠛⠻⢿⣷⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⣸⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⢻⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀
⠀⢀⡏⠀⠀⢀⣠⣶⣶⣶⣦⣤⣀⠀⠈⢻⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀
⠀⢸⠁⠀⣴⣿⣿⣿⣿⣿⣿⣿⣿⡷⠀⠈⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀
⠀⣿⠀⠀⠉⠻⣿⣿⣿⣿⡿⠋⠁⠀⠀⠀⠘⣿⣿⣿⣧⠀⠀⠀⠀⠀
⢠⣿⠀⠀⠀⠀⠀⠈⠉⠁⠀⠀⠀⠀⠀⠀⠀⠙⠛⢿⣿⠀⠀⠀⠀⠀
⢸⡇⠀⠀⣠⣴⣶⣶⣶⣶⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⠀⠀⠀
⠈⢿⣄⠀⠹⣿⣿⣿⣿⣿⠿⠋⠀⠀⠀⠀⠀⠀⠀⠀⡿⠀⠀⠀⠀⠀
⠀⠈⠻⣷⣤⣈⠙⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣧⠀⠀⠀⠀⠀
⠀⠀⠀⠈⠙⠻⠿⢿⣷⣶⣶⣶⣶⣦⣤⣤⣤⣤⣴⣾⣿⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠛⠛⠛⠛⠛⠛⠋⠁⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀"i live in the kernel"⠀⠀⠀⠀⠀
# ===========================================
#         Welcome to Not a cPanel!
#   The open-source Docker management panel.
# ===========================================
EOF

# ===========================================
#         Welcome to Not a cPanel!
#   The open-source Docker management panel.
# ===========================================

# Not a cPanel - One-line Docker Installation
# Usage: curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/install.sh | bash

set -e

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
echo "🐳 Not a cPanel - Quick Docker Setup"
echo "====================================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root for security reasons"
   exit 1
fi
# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_warning "Docker is not installed."
    read -p "Would you like to install Docker now? (Y/n): " install_docker
    install_docker=${install_docker:-Y}
    if [[ "$install_docker" =~ ^[Yy]$ ]]; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            print_status "Installing Docker using the official convenience script..."
            curl -fsSL https://get.docker.com | sh
            print_success "Docker installation complete."
        else
            print_error "Automatic Docker installation is only supported on Linux."
            echo "Please install Docker manually: https://docs.docker.com/get-docker/"
            exit 1
        fi
    else
        print_error "Docker is required to continue. Exiting."
        exit 1
    fi
else
    print_status "Docker is already installed."
# Check if Docker Compose is installed (v1 or v2)
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_warning "Docker Compose is not installed."
    read -p "Would you like to install Docker Compose now? (Y/n): " install_compose
    install_compose=${install_compose:-Y}
    if [[ "$install_compose" =~ ^[Yy]$ ]]; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            print_status "Installing Docker Compose v2 (plugin)..."
            DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
            mkdir -p $DOCKER_CONFIG/cli-plugins
            curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
            chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
            print_success "Docker Compose installation complete."
        else
            print_error "Automatic Docker Compose installation is only supported on Linux."
            echo "Please install Docker Compose manually: https://docs.docker.com/compose/install/"
            exit 1
        fi
    else
        print_error "Docker Compose is required to continue. Exiting."
        exit 1
    fi
else
    print_status "Docker Compose is already installed."
fi
fi

# Set installation directory
INSTALL_DIR="$HOME/not_a_c_panel"
REPO_URL="https://github.com/neofloppy/not_a_c_panel.git"

print_status "Installing to: $INSTALL_DIR"

# Check if git is installed
if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Please install git first."
    exit 1
fi

# Clone or update repository
if [ -d "$INSTALL_DIR" ]; then
    print_status "Directory exists, updating repository..."
    cd "$INSTALL_DIR"
    
    # Check for local changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "Local changes detected. Backing up changes..."
        git stash push -m "Auto-backup before update $(date)"
        print_status "Local changes backed up in git stash"
    fi
    
    # Pull latest changes
    if ! git pull origin master; then
        print_error "Failed to update repository. Trying to reset..."
        git fetch origin
        git reset --hard origin/master
        print_warning "Repository reset to latest version"
    fi
else
    print_status "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

print_success "Repository ready"

# Make setup scripts executable
chmod +x setup.sh
chmod +x setup-venv.sh

# Check if we need to use virtual environment approach
print_status "Checking Python environment..."
if pip3 install --dry-run flask 2>&1 | grep -q "externally-managed-environment"; then
    print_warning "Detected externally managed Python environment (Ubuntu 23.04+)"
    print_status "Using virtual environment setup method..."
    ./setup-venv.sh
else
    print_status "Using standard setup method..."
    ./setup.sh
fi

print_success "Installation complete!"

echo ""
echo "🎉 Not a cPanel is now installed!"
echo ""
read -p "Do you want to run the server now? (Y/n): " run_server
run_server=${run_server:-Y}
if [[ "$run_server" =~ ^[Yy]$ ]]; then
    cd "$INSTALL_DIR"
    echo "Starting the server..."
    python3 server.py &
    sleep 2
    echo ""
    echo "Contents of watcher.sh:"
    echo "-----------------------"
    cat watcher.sh
    echo "-----------------------"
    echo ""
    echo "Server is running. Visit: http://localhost:5000"
    echo "Login: admin / docker123!"
else
    echo "You can start the server later by running:"
    echo "  cd $INSTALL_DIR"
    echo "  python3 server.py"
    echo ""
    echo "To view watcher.sh, run: cat watcher.sh"
fi