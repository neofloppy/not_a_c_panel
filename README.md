# Not a cPanel - Docker Container Management

🐳 A modern, web-based control panel for managing Docker containers with PostgreSQL database support.

![Docker](https://img.shields.io/badge/Docker-Container%20Management-blue?style=for-the-badge&logo=docker)
![Security](https://img.shields.io/badge/Security-Authentication%20Required-green?style=for-the-badge&logo=shield)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

## 🚀 Quick Start Installation

### 🚀 Method 1: One-Line Installation (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/install_everything.sh | bash
```

**What this does:**
- ✅ Installs all system dependencies (Python3, PostgreSQL, Docker support)
- ✅ Clones the repository and installs Python packages globally
- ✅ Installs Python dependencies automatically
- ✅ Launches secure setup for credentials configuration
- ✅ Starts server with beautiful NEOFLOPPY monitoring display
- ✅ **Complete setup in one command!**

### ⚡ Method 2: Automated Installation
```bash
# Clone and run automated installer
git clone https://github.com/neofloppy/not_a_c_panel.git
cd not_a_c_panel
chmod +x install_everything.sh
./install_everything.sh
```

### 🔒 Method 3: Secure Manual Installation
```bash
# Clone the repository
git clone https://github.com/neofloppy/not_a_c_panel.git
cd not_a_c_panel

# Install system dependencies
# Ubuntu/Debian:
sudo apt update
sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential
sudo apt install -y postgresql postgresql-contrib libpq-dev

# CentOS/RHEL:
# sudo yum install -y python3 python3-pip python3-devel gcc postgresql postgresql-server postgresql-devel

# Install Python dependencies globally (production deployment)
pip3 install -r requirements.txt --break-system-packages

# Run secure startup (will configure everything)
python3 run_secure.py
```

> **Note**: The `--break-system-packages` flag is required on newer Ubuntu systems (22.04+) for production deployments where you want to install packages globally. This is safe for dedicated servers running only Not a cPanel.

## 📋 What Happens During Setup

When you run the **One-Line Installation** or `python run_secure.py`, the script will:

1. **Check Dependencies**: Verify Python version and required packages
2. **Environment Setup**: Create necessary directories (nginx-configs, web-content, logs)
3. **Configuration Prompts**: Ask you to configure:
   - **Server IP Address**: Your server's IP (default: 0.0.0.0 for external access)
   - **Admin Username**: Control panel username (default: admin)
   - **Admin Password**: Control panel password (secure input, hidden while typing)
   - **Database Settings**: PostgreSQL connection details
4. **Firewall Configuration**: Automatically open required ports:
   - Port 5000: Main application
   - Port 80: HTTP containers
   - Port 443: HTTPS containers  
   - Port 5432: PostgreSQL
   - Ports 8000-8005: Container web services
5. **Start Server**: Launch the secure web interface
6. **🎯 Launch Monitor**: Automatically display the beautiful NEOFLOPPY monitoring interface

### First Run Configuration
On first run, you'll see prompts like:
```
🔐 Setting up admin password...
Enter admin password (min 6 characters): [hidden input]
Confirm admin password: [hidden input]
✅ Password set successfully!

Enter server IP (current: 0.0.0.0): [your-server-ip]
Enter admin username (current: admin): [your-username]
Enter database host (current: localhost): 
Configure firewall ports automatically? (Y/n): y

🚀 Starting secure server...
🖥️  Starting monitoring display...
🎯 Launching monitoring display...

[Beautiful NEOFLOPPY ASCII art appears with live monitoring]
```

### Subsequent Runs
On subsequent runs, the script will:
- Load existing configuration
- Ask if you want to reconfigure (y/N)
- Ask about firewall configuration
- Start the server with your saved settings
- **Automatically display the NEOFLOPPY monitoring interface**

## 🔐 Access Information

After successful setup:
- **URL**: `http://your-server-ip:5000`
- **Username**: As configured during setup (default: admin)
- **Password**: As set during setup

## 🌟 Features

### Container Management
- **Dashboard**: Overview of all Docker containers and system status
- **Container Control**: Start, stop, restart, and monitor containers
- **Real-time Monitoring**: CPU, memory, and network usage
- **Log Viewer**: Access container logs in real-time
- **Shell Access**: Execute commands inside containers

### Web Server Management
- **Nginx Configuration**: Edit and manage Nginx configs for each container
- **Auto-Configuration**: Automatic setup for new containers
- **Port Management**: Automatic port assignment and conflict resolution
- **SSL/HTTPS Support**: Configure secure connections

### Database Management
- **PostgreSQL Integration**: Full PostgreSQL server management
- **Database Operations**: Create/drop databases, manage users
- **SQL Console**: Execute queries with real-time results
- **Connection Management**: Get connection strings for applications

### Security Features
- **Authentication**: Secure login system with session management
- **Rate Limiting**: Protection against brute force attacks
- **Input Validation**: Sanitized command execution
- **Firewall Integration**: Automatic port configuration
- **Secure Configuration**: Encrypted password storage

## 🛠️ System Requirements

### Minimum Requirements
- **Operating System**: Linux (Ubuntu 18.04+), Windows 10+, macOS 10.14+
- **Python**: 3.8 or higher
- **Memory**: 512MB RAM minimum, 1GB recommended
- **Storage**: 1GB free space
- **Network**: Internet connection for initial setup

### Supported Platforms
- ✅ **Ubuntu/Debian**: Full support with UFW firewall
- ✅ **CentOS/RHEL/Fedora**: Full support with iptables
- ✅ **Windows**: Full support with Windows Firewall
- ✅ **macOS**: Basic support (manual firewall configuration)

### Dependencies (Auto-installed)
- Flask (web framework)
- psycopg2 (PostgreSQL adapter)
- Flask-Limiter (rate limiting)
- Flask-CORS (cross-origin requests)
- Werkzeug (security utilities)

## 🔧 Configuration

### Configuration File
Settings are stored in `config.ini`:
```ini
[server]
ip = 0.0.0.0
username = admin

[admin]
password_hash = [encrypted-password-hash]

[database]
host = localhost
database = notacpanel
user = notacpanel
password = notacpanel123
port = 5432

[security]
debug = False
force_https = False
session_timeout_hours = 4
max_login_attempts = 5
lockout_duration_minutes = 15
```

### Reconfiguration
To change settings after initial setup:
```bash
python run_secure.py
# When prompted: "Reconfigure settings? (y/N):" type 'y'
```

### Manual Configuration
You can also edit `config.ini` directly, then restart the server.

## 🚨 Troubleshooting

### Common Issues

**1. "Python 3.8+ is required for security reasons"**
```bash
# Update Python on Ubuntu:
sudo apt update
sudo apt install python3.8 python3.8-venv python3.8-dev

# Create venv with specific version:
python3.8 -m venv venv
```

**2. "psycopg2 not found" or "pg_config executable not found"**
```bash
# Ubuntu/Debian:
sudo apt install python3-dev build-essential libpq-dev postgresql-client

# CentOS/RHEL:
sudo yum install python3-devel gcc postgresql-devel

# Then reinstall:
pip install psycopg2-binary
```

**3. "Permission denied" for firewall configuration**
```bash
# Linux: Run with sudo for firewall access
sudo python run_secure.py

# Windows: Run Command Prompt as Administrator
```

**4. "Port 5000 already in use"**
```bash
# Find what's using the port:
netstat -tulpn | grep :5000
# Or on Windows:
netstat -ano | findstr :5000

# Kill the process or change port in server.py
```

**5. "Docker not found"**
```bash
# Install Docker:
# Ubuntu:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Restart session or run:
newgrp docker
```

### Firewall Issues

**Linux (UFW not working):**
```bash
# Manual iptables rules:
sudo iptables -A INPUT -p tcp --dport 5000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5432 -j ACCEPT

# Save rules (Ubuntu):
sudo iptables-save > /etc/iptables/rules.v4
```

**Windows (Firewall rules not applying):**
```cmd
REM Run as Administrator:
netsh advfirewall firewall add rule name="Not-a-cPanel-5000" dir=in action=allow protocol=TCP localport=5000
netsh advfirewall firewall add rule name="Not-a-cPanel-80" dir=in action=allow protocol=TCP localport=80
netsh advfirewall firewall add rule name="Not-a-cPanel-443" dir=in action=allow protocol=TCP localport=443
```

### Database Connection Issues
```bash
# Check PostgreSQL status:
sudo systemctl status postgresql

# Start PostgreSQL:
sudo systemctl start postgresql

# Create database manually:
sudo -u postgres createdb notacpanel
sudo -u postgres createuser notacpanel
sudo -u postgres psql -c "ALTER USER notacpanel PASSWORD 'notacpanel123';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE notacpanel TO notacpanel;"
```

## 📊 API Documentation

### Authentication
All API endpoints require authentication via session cookies.

### Container Endpoints
- `GET /api/containers` - List all containers
- `POST /api/containers` - Create new container
- `POST /api/containers/{id}/start` - Start container
- `POST /api/containers/{id}/stop` - Stop container
- `POST /api/containers/{id}/restart` - Restart container
- `DELETE /api/containers/{id}` - Remove container

### Database Endpoints
- `POST /api/postgresql/execute` - Execute SQL query
- `GET /api/postgresql/status` - Get database status

### System Endpoints
- `POST /api/login` - Authenticate user
- `POST /api/logout` - End session

## 🔒 Security Considerations

### Production Deployment
For production use, consider:

1. **HTTPS/SSL**: Enable SSL certificates
2. **Reverse Proxy**: Use Nginx/Apache as reverse proxy
3. **Firewall**: Restrict access to necessary ports only
4. **Updates**: Keep system and dependencies updated
5. **Monitoring**: Implement logging and monitoring
6. **Backups**: Regular database and configuration backups

### Security Features
- Password hashing with PBKDF2
- Session management with timeouts
- Rate limiting on login attempts
- Input validation and sanitization
- CORS protection
- Command execution restrictions

## 📁 File Structure

```
not_a_c_panel/
├── run_secure.py       # Secure startup script
├── server.py           # Main Flask application
├── config.ini          # Configuration file (created on first run)
├── index.html          # Web interface
├── styles.css          # Application styling
├── script.js           # Frontend JavaScript
├── requirements.txt    # Python dependencies
├── install_everything.sh # Automated installer
├── nginx-configs/      # Nginx configuration files
├── web-content/        # Web content for containers
├── logs/              # Application logs
└── README.md          # This file
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For help and support:

1. **Check this README** for common solutions
2. **Review logs** in the terminal where the server is running
3. **Check system logs**: `/var/log/syslog` (Linux) or Event Viewer (Windows)
4. **Create an issue** on GitHub with:
   - Your operating system
   - Python version (`python --version`)
   - Error messages
   - Steps to reproduce

## 🎯 Quick Commands Reference

```bash
# Start the application
python run_secure.py

# Reconfigure settings
python run_secure.py
# Then answer 'y' to "Reconfigure settings?"

# Check if server is running
curl http://localhost:5000

# View application logs
tail -f logs/not_a_cpanel.log

# Check Docker containers
docker ps -a

# Test database connection
psql -h localhost -U notacpanel -d notacpanel
```

---

**🐳 Not a cPanel** - Making container management simple and secure!