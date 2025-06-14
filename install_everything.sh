#!/bin/sh

# Not a cPanel - Minimal Bootstrap Installer (POSIX sh compatible)
# Installs Python, pip, git, clones the repo, and prints next steps.

set -e

REPO_URL="https://github.com/neofloppy/not_a_c_panel.git"
REPO_NAME="not_a_c_panel"

echo "=============================================="
echo "  Not a cPanel - Minimal Bootstrap Installer"
echo "=============================================="

print_status() { echo "[INFO] $1"; }
print_success() { echo "[SUCCESS] $1"; }
print_error() { echo "[ERROR] $1"; }

print_status "Checking for Python 3, pip, and git..."

# Install Python3, pip, git if missing
if ! command -v python3 >/dev/null 2>&1; then
    print_status "Python3 not found. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y python3
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y python3
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm python
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y python3
    else
        print_error "Unsupported package manager. Please install Python3 manually."
        exit 1
    fi
fi

if ! command -v pip3 >/dev/null 2>&1; then
    print_status "pip3 not found. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y python3-pip
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y python3-pip
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3-pip
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm python-pip
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y python3-pip
    else
        print_error "Unsupported package manager. Please install pip3 manually."
        exit 1
    fi
fi

if ! command -v git >/dev/null 2>&1; then
    print_status "git not found. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get install -y git
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y git
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y git
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm git
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y git
    else
        print_error "Unsupported package manager. Please install git manually."
        exit 1
    fi
fi

print_success "Python3, pip3, and git are installed."

# Clone the repo if not present
if [ ! -d "$REPO_NAME" ]; then
    print_status "Cloning repository..."
    git clone "$REPO_URL"
else
    print_status "Repository already cloned."
fi

cd "$REPO_NAME"

print_status "Installing Python dependencies..."
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

print_success "Python dependencies installed."

echo ""
print_status "To start the backend server, run:"
echo "python3 server.py"
print_status "Then open your browser to the app and complete setup (including Docker/PostgreSQL) from the web interface."
print_success "Bootstrap complete!"