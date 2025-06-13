# One-Line Docker Setup for Not a cPanel

## Quick Installation via curl

For Linux servers, you can install and set up the entire Not a cPanel system with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/install.sh | bash
```

## What this command does:

1. **Downloads the installation script** from GitHub
2. **Clones the repository** to `~/not_a_c_panel`
3. **Checks prerequisites** (Docker, Docker Compose, Python 3)
4. **Installs pip3** automatically if not present
5. **Creates directory structure** for Nginx configurations
6. **Generates default configurations** for 10 Nginx containers
7. **Installs Python dependencies** (Flask, Flask-CORS)
8. **Pulls Docker images** (nginx:alpine)
9. **Starts 10 Docker containers** with Nginx
10. **Tests connectivity** to all containers
11. **Provides next steps** to start the control panel

## Alternative: Step-by-step

If you prefer to see what's happening:

```bash
# Download the install script
curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/install.sh -o install.sh

# Review the script (optional)
cat install.sh

# Make it executable and run
chmod +x install.sh
./install.sh
```

## After Installation

Once the installation completes:

```bash
# Navigate to the installation directory
cd ~/not_a_c_panel

# Start the control panel
python3 server.py
```

Then access the control panel at:
- **Local**: http://localhost:5000
- **Remote**: http://your-server-ip:5000

**Login credentials:**
- Username: `admin`
- Password: `docker123!`

## Container Access

After setup, you'll have 10 Nginx containers running on ports 8001-8010:

- http://localhost:8001 (web-01)
- http://localhost:8002 (web-02)
- http://localhost:8003 (web-03)
- http://localhost:8004 (web-04)
- http://localhost:8005 (web-05)
- http://localhost:8006 (api-01)
- http://localhost:8007 (api-02)
- http://localhost:8008 (lb-01)
- http://localhost:8009 (static-01)
- http://localhost:8010 (proxy-01)

## Testing the Setup

Run the test script to verify everything is working:

```bash
cd ~/not_a_c_panel
chmod +x test-setup.sh
./test-setup.sh
```

## Requirements

The installation script will check for these prerequisites:

- **Linux server** (Ubuntu 18.04+ recommended)
- **Docker** (will provide installation instructions if missing)
- **Docker Compose** (will provide installation instructions if missing)
- **Python 3.6+** (usually pre-installed on modern Linux)
- **pip3** (will be installed automatically if missing)
- **Git** (for cloning the repository)
- **curl** (for downloading the script)

## Troubleshooting

If the installation fails:

1. **Check Docker status**: `sudo systemctl status docker`
2. **Verify user permissions**: `groups $USER` (should include 'docker')
3. **Check available ports**: `netstat -tulpn | grep :500[0-9]`
4. **Review logs**: Check terminal output for specific error messages

## Security Note

This setup is intended for development and testing. For production use:

1. Change default login credentials
2. Set up SSL/HTTPS
3. Configure firewall rules
4. Use strong passwords
5. Keep system updated

## Example Usage on Fresh Ubuntu Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker (if not installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Install Not a cPanel
curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/install.sh | bash

# Start the control panel
cd ~/not_a_c_panel
python3 server.py
```

That's it! Your Docker container management system is ready to use.