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

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo ""
    echo "Docker is not installed."
    read -p "Would you like to install Docker now? (Y/n): " install_docker
    install_docker=${install_docker:-Y}
    if [[ "$install_docker" =~ ^[Yy]$ ]]; then
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "Installing Docker using the official convenience script..."
            curl -fsSL https://get.docker.com | sh
            echo "Docker installation complete."
        else
            echo "Automatic Docker installation is only supported on Linux."
            echo "Please install Docker manually: https://docs.docker.com/get-docker/"
            exit 1
        fi
    else
        echo "Docker is required to continue. Exiting."
        exit 1
    fi
else
    echo "Docker is already installed."
fi

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

# ... (rest of the original install logic should be restored here, including all steps, checks, and the final prompt to run the server and display watcher.sh)