#!/bin/sh

# Not a cPanel - Minimal Bootstrap Installer (POSIX sh compatible)
# Installs Python, pip, git, clones the repo, sets up a venv, and installs requirements.

set -e

REPO_URL="https://github.com/neofloppy/not_a_c_panel.git"
REPO_NAME="not_a_c_panel"
VENV_DIR="venv"

echo "=============================================="
echo "  Not a cPanel - Minimal Bootstrap Installer"
echo "=============================================="

print_status() { echo "[INFO] $1"; }
print_success() { echo "[SUCCESS] $1"; }
print_error() { echo "[ERROR] $1"; }
print_warning() { echo "[WARNING] $1"; }

print_status "Checking for Python 3, pip, git, and PostgreSQL development packages..."

# Install Python3, pip, git, PostgreSQL dev packages if missing
if ! command -v python3 >/dev/null 2>&1; then
    print_status "Python3 not found. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y python3 python3-venv python3-dev build-essential
        sudo apt-get install -y postgresql postgresql-contrib libpq-dev
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y python3 python3-venv python3-devel gcc
        sudo yum install -y postgresql postgresql-server postgresql-devel
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3 python3-venv python3-devel gcc
        sudo dnf install -y postgresql postgresql-server postgresql-devel
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm python python-venv base-devel
        sudo pacman -Sy --noconfirm postgresql postgresql-libs
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y python3 python3-venv python3-devel gcc
        sudo zypper install -y postgresql postgresql-server-devel
    else
        print_error "Unsupported package manager. Please install Python3, python3-venv, python3-dev, build-essential, postgresql, and libpq-dev manually."
        exit 1
    fi
fi
# Ensure PostgreSQL development packages are installed
print_status "Ensuring PostgreSQL development packages are installed..."
if command -v apt-get >/dev/null 2>&1; then
    if ! dpkg -l | grep -q libpq-dev; then
        print_status "Installing PostgreSQL development packages..."
        sudo apt-get update
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

# Check if python3-venv is available (fixes ensurepip error)
if ! python3 -m venv --help >/dev/null 2>&1; then
    print_status "python3-venv is not available. Installing..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y python3-venv
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y python3-venv
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y python3-venv
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm python-venv
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y python3-venv
    else
        print_error "Unsupported package manager. Please install python3-venv manually."
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

# Set up Python virtual environment
if [ ! -d "$VENV_DIR" ]; then
    print_status "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

print_status "Activating virtual environment..."
. "$VENV_DIR/bin/activate"

print_status "Installing Python dependencies in venv..."
pip install --upgrade pip
pip install -r requirements.txt

print_success "Python dependencies installed in venv."

echo ""
print_status "To start the backend server, run:"
echo ". venv/bin/activate && python server.py"
print_status "Then open your browser to the app and complete setup (including Docker/PostgreSQL) from the web interface."

# Prompt to start server and watcher
echo ""
printf "Do you want to start the backend server and watcher now? (y/n): "
read START_NOW
if [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
    print_status "Starting backend server in background..."
    nohup "$VENV_DIR/bin/python" server.py > server.log 2>&1 &
    if [ -f watcher.sh ]; then
        print_status "Starting watcher.sh in background..."
        chmod +x watcher.sh
        nohup ./watcher.sh > watcher.log 2>&1 &
    else
        print_warning "watcher.sh not found, skipping."
    fi
    print_success "Backend server and watcher started. Check server.log and watcher.log for output."
else
    print_status "You can start the backend server anytime with: . venv/bin/activate && python server.py"
    print_status "And watcher (if needed) with: ./watcher.sh"
fi

print_success "Bootstrap complete!"