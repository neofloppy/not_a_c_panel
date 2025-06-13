#!/bin/bash

# Fix installation script for handling local changes
# This script resolves the merge conflict and updates the installation

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
echo "🔧 Not a cPanel - Installation Fix"
echo "=================================="
echo ""

# Set installation directory
INSTALL_DIR="$HOME/not_a_c_panel"

# Check if we're in the right directory
if [ ! -d "$INSTALL_DIR" ]; then
    print_error "Installation directory not found: $INSTALL_DIR"
    exit 1
fi

cd "$INSTALL_DIR"

print_status "Resolving merge conflicts..."

# Stash any local changes
print_status "Backing up local changes..."
git stash push -m "Backup before update $(date)"

# Pull the latest changes
print_status "Pulling latest updates..."
git pull origin master

# Check if there were stashed changes
if git stash list | grep -q "Backup before update"; then
    print_warning "Your local changes have been backed up in git stash"
    print_status "You can restore them later with: git stash pop"
fi

print_success "Repository updated successfully!"

# Make scripts executable
chmod +x setup.sh
chmod +x install.sh
chmod +x test-setup.sh

print_status "Running updated setup script..."
./setup.sh

print_success "Installation fix complete!"

echo ""
echo "🎉 Not a cPanel is now updated and ready!"
echo ""
echo "To start the control panel:"
echo "  cd $INSTALL_DIR"
echo "  python3 server.py"
echo ""
echo "Then visit: http://localhost:5000"
echo "Login: admin / docker123!"
echo ""