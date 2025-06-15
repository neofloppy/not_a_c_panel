#!/bin/sh

# Not a cPanel - Minimal Bootstrap Installer (POSIX sh compatible)
# Installs Python, pip, git, clones the repo, sets up a venv, and installs requirements.

set -e

REPO_URL="https://github.com/neofloppy/not_a_c_panel.git"
REPO_NAME="not_a_c_panel"

echo "=============================================="
echo "  Not a cPanel - Minimal Bootstrap Installer"
echo "=============================================="

print_status() { echo "[INFO] $1"; }
print_success() { echo "[SUCCESS] $1"; }
print_error() { echo "[ERROR] $1"; }
print_warning() { echo "[WARNING] $1"; }

print_status "Checking for Python 3, pip, git, and PostgreSQL development packages..."

# Check and fix system time if needed (common issue with VMs)
if command -v timedatectl >/dev/null 2>&1; then
    print_status "Checking system time..."
    if ! timedatectl status | grep -q "synchronized: yes"; then
        print_status "Synchronizing system time..."
        sudo timedatectl set-ntp true 2>/dev/null || true
        sleep 2
    fi
fi

# Install Python3, pip, git, PostgreSQL dev packages if missing
if ! command -v python3 >/dev/null 2>&1; then
    print_status "Python3 not found. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update --allow-releaseinfo-change || sudo apt-get update
        sudo apt-get install -y python3 python3-pip python3-dev build-essential
        sudo apt-get install -y postgresql postgresql-contrib libpq-dev
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y python3 python3-pip python3-devel gcc
        sudo yum install -y postgresql postgresql-server postgresql-devel
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3 python3-pip python3-devel gcc
        sudo dnf install -y postgresql postgresql-server postgresql-devel
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm python python-pip base-devel
        sudo pacman -Sy --noconfirm postgresql postgresql-libs
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y python3 python3-pip python3-devel gcc
        sudo zypper install -y postgresql postgresql-server-devel
    else
        print_error "Unsupported package manager. Please install Python3, python3-pip, python3-dev, build-essential, postgresql, and libpq-dev manually."
        exit 1
    fi
fi
# Ensure PostgreSQL development packages are installed
print_status "Ensuring PostgreSQL development packages are installed..."
if command -v apt-get >/dev/null 2>&1; then
    if ! dpkg -l | grep -q libpq-dev; then
        print_status "Installing PostgreSQL development packages..."
        sudo apt-get update --allow-releaseinfo-change || sudo apt-get update
        sudo apt-get install -y python3-dev build-essential
        sudo apt-get install -y postgresql postgresql-contrib libpq-dev
    fi
elif command -v yum >/dev/null 2>&1; then
    if ! rpm -qa | grep -q postgresql-devel; then
        print_status "Installing PostgreSQL development packages..."
        sudo yum install -y python3-devel gcc
        sudo yum install -y postgresql postgresql-server postgresql-devel
    fi
elif command -v dnf >/dev/null 2>&1; then
    if ! rpm -qa | grep -q postgresql-devel; then
        print_status "Installing PostgreSQL development packages..."
        sudo dnf install -y python3-devel gcc
        sudo dnf install -y postgresql postgresql-server postgresql-devel
    fi
elif command -v pacman >/dev/null 2>&1; then
    if ! pacman -Qs postgresql-libs >/dev/null 2>&1; then
        print_status "Installing PostgreSQL development packages..."
        sudo pacman -Sy --noconfirm base-devel
        sudo pacman -Sy --noconfirm postgresql postgresql-libs
    fi
elif command -v zypper >/dev/null 2>&1; then
    if ! rpm -qa | grep -q postgresql-server-devel; then
        print_status "Installing PostgreSQL development packages..."
        sudo zypper install -y python3-devel gcc
        sudo zypper install -y postgresql postgresql-server-devel
    fi
fi

if ! command -v pip3 >/dev/null 2>&1; then
    print_status "pip3 not found. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update --allow-releaseinfo-change || sudo apt-get update
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
        sudo apt-get update --allow-releaseinfo-change || sudo apt-get update
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

print_status "Installing Python dependencies globally..."
pip3 install --upgrade pip --break-system-packages
pip3 install -r requirements.txt --break-system-packages

print_success "Python dependencies installed globally."

echo ""
print_success "Installation complete!"
echo ""
print_status "🔐 NEXT STEPS:"
echo "   1. cd $REPO_NAME"
echo "   2. python3 run_secure.py"
echo ""
print_status "The secure setup will:"
echo "   - Prompt you to set up admin credentials"
echo "   - Configure database settings"
echo "   - Set up firewall rules"
echo "   - Start the secure server"
echo ""
print_status "Alternative: Start server directly (not recommended for first run):"
echo "   python3 server.py"
echo ""

# Always run secure setup automatically
print_status "Starting secure setup automatically..."
echo ""

# Check if running via pipe (curl | bash) - need to reopen stdin from terminal
if [ ! -t 0 ]; then
    print_status "Detected non-interactive mode (curl | bash)"
    print_status "Reopening terminal input for secure setup..."
    # Reopen stdin from the controlling terminal
    exec < /dev/tty 2>/dev/null || {
        print_error "Cannot access terminal for interactive setup"
        print_status "Please run these commands manually:"
        echo "   cd $REPO_NAME"
        echo "   python3 run_secure.py"
        exit 1
    }
fi

# Run the secure setup
python3 run_secure.py

print_success "Bootstrap complete!"