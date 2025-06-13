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