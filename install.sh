#!/bin/bash

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

# Make setup script executable
chmod +x setup.sh

print_status "Running setup script..."
./setup.sh

print_success "Installation complete!"

echo ""
echo "🎉 Not a cPanel is now installed!"
echo ""
echo "To start the control panel:"
echo "  cd $INSTALL_DIR"
echo "  python3 server.py"
echo ""
echo "Then visit: http://localhost:5000"
echo "Login: admin / docker123!"
echo ""