# Not a cPanel - Docker Container Management

🐳 A modern, web-based control panel for managing Docker containers on Ubuntu servers.

![Ubuntu](https://img.shields.io/badge/Ubuntu-Only-orange?style=for-the-badge&logo=ubuntu)
![Docker](https://img.shields.io/badge/Docker-Container%20Management-blue?style=for-the-badge&logo=docker)
![Security](https://img.shields.io/badge/Security-Authentication%20Required-green?style=for-the-badge&logo=shield)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

## 🚀 Ubuntu Installation

### 🔒 Method 1: Secure Manual Installation (Recommended)
```bash
# Clone the repository
git clone https://github.com/neofloppy/not_a_c_panel.git
cd not_a_c_panel

# Install system dependencies (Python3, PostgreSQL dev packages, build tools)
sudo apt update
sudo apt install -y python3 python3-pip python3-venv python3-dev build-essential
sudo apt install -y postgresql postgresql-contrib libpq-dev

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run secure startup (will prompt for configuration)
python run_secure.py
```

### ⚡ Method 2: Automated Installation
```bash
# Clone the repository
git clone https://github.com/neofloppy/not_a_c_panel.git
cd not_a_c_panel

# Run the automated installer (handles all dependencies)
chmod +x install_everything.sh
./install_everything.sh
```

### 🚀 Method 3: One-Line Installation
```bash
# Download and run the installer directly
curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/install_everything.sh | bash
```

**During installation, you'll be prompted for:**
- **Server IP Address**: Your server's public IP address
- **Admin Username**: Username for the control panel
- **Admin Password**: Password for the control panel
- **PostgreSQL Host**: Database host (default: localhost)
- **PostgreSQL Port**: Database port (default: 5432)
- **PostgreSQL User**: Database user (default: postgres)
- **PostgreSQL Password**: Database password (default: postgres)
- **PostgreSQL Database Name**: Database name (default: notacpanel)

## 🛠️ Ubuntu Troubleshooting

**Python virtual environment creation fails with `ensurepip is not available`**

If you see an error like:
```
The virtual environment was not created successfully because ensurepip is not available.
```
On Ubuntu systems, install the venv package:
```bash
sudo apt install python3-venv
```
After installing, retry the setup.

**PostgreSQL dependency installation fails with `pg_config executable not found`**

If you see an error like:
```
Error: pg_config executable not found.
pg_config is required to build psycopg2 from source.
```
This means PostgreSQL development packages are missing. Install them:

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y python3-dev build-essential postgresql postgresql-contrib libpq-dev
```

**CentOS/RHEL:**
```bash
sudo yum install -y python3-devel gcc postgresql postgresql-server postgresql-devel
```

**Fedora:**
```bash
sudo dnf install -y python3-devel gcc postgresql postgresql-server postgresql-devel
```

**Arch Linux:**
```bash
sudo pacman -Sy --noconfirm base-devel postgresql postgresql-libs
```

After installing these packages, retry:
```bash
pip install -r requirements.txt
```

### Access the Control Panel
- URL: `http://your-server-ip:5000` (as configured during installation)
- Username: `admin`
- Password: `[your-chosen-password]` (as set during installation)

### Database Access
- Host: `localhost:5432`
- Database: `notacpanel`
- Username: `notacpanel`
- Password: `[your-chosen-db-password]` (as set during installation)

## 🌟 Features

- **Dashboard**: Overview of all Docker containers and system resources
- **Container Management**: Start, stop, restart, and monitor Docker containers
- **Nginx Configuration**: Edit and manage Nginx configurations for each container
- **PostgreSQL Management**: Install, configure, and manage PostgreSQL database server
- **Database Operations**: Create/drop databases, manage users, execute SQL queries
- **Real-time Monitoring**: View CPU, memory, and network usage for containers
- **Log Viewer**: Access and follow container logs in real-time
- **Terminal Access**: Execute commands on the host system or inside containers
- **Responsive Design**: Works on desktop and mobile devices

## 📋 Ubuntu Requirements

- **Ubuntu Server** (18.04 LTS or newer)
- **Docker** installed and running
- **Python 3.6+** (installed during setup)
- **PostgreSQL development packages** (installed during setup)
- **Build tools** (gcc, make, etc. - installed during setup)
- **Internet connection** for package installation

### System Dependencies (Auto-installed)
The installation process automatically installs these system packages:
- `python3`, `python3-pip`, `python3-venv`, `python3-dev`
- `build-essential` (gcc, make, libc6-dev)
- `postgresql`, `postgresql-contrib`, `libpq-dev`
- `git`

## 🔐 Login Credentials

The control panel is protected by authentication. Credentials are configured during installation:

- **Username**: Set during secure installation
- **Password**: Set during secure installation (or auto-generated)

> **Security Note**: Use the secure installation method (`run_secure.py`) to set strong credentials. Never use default passwords in production.

## Usage

### Dashboard
- View overview of all containers and their status
- Monitor system resources (CPU, memory, disk usage)
- Quick access to common actions

### Container Management
- **Start/Stop/Restart**: Control individual containers or all at once
- **View Details**: Click on any container to see detailed information
- **Execute Shell**: Access container shell directly from the interface

### Nginx Management
- **Configuration Editor**: Edit Nginx configurations with syntax highlighting
- **Test Configuration**: Validate Nginx configs before applying
- **Reload Nginx**: Apply configuration changes without restarting containers

### PostgreSQL Management
- **Installation**: One-click PostgreSQL server installation
- **Service Control**: Start, stop, and restart PostgreSQL service
- **Database Management**: Create, drop, and manage databases
- **User Management**: Create users, set permissions, change passwords
- **SQL Console**: Execute SQL queries with real-time results
- **Connection Info**: Get connection strings for various programming languages

### Monitoring
- **Real-time Stats**: View CPU, memory, and network usage
- **Auto-refresh**: Enable automatic updates every 5 seconds
- **Historical Data**: Track resource usage over time

### Logs
- **Container Logs**: View logs from any container
- **Follow Mode**: Continuously stream new log entries
- **Search and Filter**: Find specific log entries

### Terminal
- **Host Terminal**: Execute commands on the Ubuntu server
- **Container Shell**: Access bash/sh inside any running container
- **Command History**: Previous commands are remembered

## API Endpoints

The backend provides a REST API for all operations:

### Containers
- `GET /api/containers` - List all containers
- `POST /api/containers/{id}/start` - Start container
- `POST /api/containers/{id}/stop` - Stop container
- `POST /api/containers/{id}/restart` - Restart container
- `GET /api/containers/{id}/logs` - Get container logs
- `POST /api/containers/{id}/exec` - Execute command in container

### Nginx Management
- `GET /api/containers/{id}/nginx/config` - Get Nginx config
- `POST /api/containers/{id}/nginx/config` - Update Nginx config
- `POST /api/containers/{id}/nginx/reload` - Reload Nginx
- `POST /api/containers/{id}/nginx/test` - Test Nginx config

### PostgreSQL Management
- `GET /api/postgresql/status` - Get PostgreSQL installation and service status
- `POST /api/postgresql/install` - Install PostgreSQL server
- `POST /api/postgresql/start` - Start PostgreSQL service
- `POST /api/postgresql/stop` - Stop PostgreSQL service
- `POST /api/postgresql/restart` - Restart PostgreSQL service
- `GET /api/postgresql/databases` - List all databases
- `POST /api/postgresql/databases` - Create new database
- `DELETE /api/postgresql/databases/{name}` - Drop database
- `GET /api/postgresql/users` - List all database users
- `POST /api/postgresql/users` - Create new user
- `DELETE /api/postgresql/users/{username}` - Drop user
- `POST /api/postgresql/users/{username}/password` - Change user password
- `POST /api/postgresql/execute` - Execute SQL query

### System
- `GET /api/system/info` - Get system information
- `POST /api/system/command` - Execute system command

## Configuration

### Automatic Configuration
Configuration is handled automatically during installation. The installer creates a `config.py` file with your settings:

```python
SERVER_IP = "your-server-ip"     # Set during installation
USERNAME = "your-username"       # Set during installation  
ADMIN_PASSWORD = "your-password" # Set during installation
```

### Manual Configuration Changes
To change configuration after installation:
1. Edit `config.py` with your new values
2. Run `python3 update-templates.py` to update interface files
3. Restart the control panel: `python3 server.py`

### Docker Compose
Modify `docker-compose.yml` to customize:
- Container names
- Port mappings
- Volume mounts
- Nginx configurations

### Security
The application includes basic security measures:
- Command whitelist for system execution
- Input validation
- CORS protection

For production use, consider adding:
- Authentication/authorization
- HTTPS/SSL certificates
- Firewall rules
- Rate limiting

## File Structure

```
not_a_c_panel/
├── index.html          # Main application interface
├── styles.css          # Application styling
├── script.js           # Frontend JavaScript
├── server.py           # Backend Flask server
├── docker-compose.yml  # Docker container definitions
├── README.md           # This file
└── nginx-configs/      # Nginx configuration files
    ├── web-01/
    ├── web-02/
    ├── ...
    └── proxy-01/
```

## Troubleshooting

### Common Issues

1. **Containers not showing up**
   - Ensure Docker is running: `sudo systemctl status docker`
   - Check container status: `docker ps -a`

2. **Permission denied errors**
   - Add user to docker group: `sudo usermod -aG docker $USER`
   - Restart session or run: `newgrp docker`

3. **Port conflicts**
   - Check if ports are in use: `netstat -tulpn | grep :5000`
   - Modify port in `server.py` if needed

4. **Nginx configuration errors**
   - Test config manually: `docker exec <container> nginx -t`
   - Check container logs: `docker logs <container>`

### Logs and Debugging

- Application logs: Check terminal where `server.py` is running
- Container logs: Use the log viewer in the interface or `docker logs`
- System logs: `/var/log/syslog` or `journalctl -u docker`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source and available under the MIT License.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Docker and system logs
3. Create an issue in the repository

---

**Note**: This is a basic control panel for demonstration purposes. For production use, implement proper security measures, authentication, and monitoring.