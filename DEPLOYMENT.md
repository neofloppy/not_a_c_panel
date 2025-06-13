# Deployment Guide - Not a cPanel

This guide explains how to deploy Not a cPanel on a Linux server using Docker.

## Prerequisites

- Ubuntu 18.04+ or similar Linux distribution
- Root or sudo access
- Internet connection

## Quick Deployment

### Method 1: One-line Installation (Recommended)

```bash
# Install everything with one command
curl -fsSL https://raw.githubusercontent.com/neofloppy/not_a_c_panel/master/install.sh | bash
```

This will:
1. Clone the repository
2. Install dependencies
3. Set up Docker containers
4. Configure Nginx instances
5. Start the control panel

### Method 2: Step-by-step Installation

```bash
# 1. Install Docker (if not already installed)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# 2. Install Docker Compose (if not already installed)
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 3. Clone the repository
git clone https://github.com/neofloppy/not_a_c_panel.git
cd not_a_c_panel

# 4. Run the setup script
chmod +x setup.sh
./setup.sh
```

## Server Configuration

### Firewall Setup

If you're using UFW (Ubuntu Firewall):

```bash
# Allow SSH (if not already allowed)
sudo ufw allow ssh

# Allow the control panel port
sudo ufw allow 5000

# Allow container ports (optional, for direct access)
sudo ufw allow 8001:8010/tcp

# Enable firewall
sudo ufw enable
```

### Systemd Service (Optional)

To run the control panel as a system service:

```bash
# Create service file
sudo tee /etc/systemd/system/not-a-cpanel.service > /dev/null <<EOF
[Unit]
Description=Not a cPanel - Docker Container Management
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/not_a_c_panel
ExecStart=/usr/bin/python3 server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable not-a-cpanel
sudo systemctl start not-a-cpanel

# Check status
sudo systemctl status not-a-cpanel
```

## Access Configuration

### Local Access
- URL: `http://localhost:5000`
- Username: `admin`
- Password: `docker123!`

### Remote Access
- URL: `http://your-server-ip:5000`
- Username: `admin`
- Password: `docker123!`

### Nginx Reverse Proxy (Optional)

To use a custom domain with SSL:

```bash
# Install Nginx
sudo apt update
sudo apt install nginx

# Create configuration
sudo tee /etc/nginx/sites-available/not-a-cpanel > /dev/null <<EOF
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/not-a-cpanel /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Install SSL with Let's Encrypt (optional)
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## Container Management

### Container Ports
- web-01: http://localhost:8001
- web-02: http://localhost:8002
- web-03: http://localhost:8003
- web-04: http://localhost:8004
- web-05: http://localhost:8005
- api-01: http://localhost:8006
- api-02: http://localhost:8007
- lb-01: http://localhost:8008
- static-01: http://localhost:8009
- proxy-01: http://localhost:8010

### Useful Commands

```bash
# Check container status
docker-compose ps

# View container logs
docker-compose logs [container-name]

# Restart all containers
docker-compose restart

# Stop all containers
docker-compose down

# Start all containers
docker-compose up -d

# Update containers
docker-compose pull
docker-compose up -d
```

## Testing the Installation

Run the test script to verify everything is working:

```bash
chmod +x test-setup.sh
./test-setup.sh
```

## Troubleshooting

### Common Issues

1. **Permission denied errors**
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Port already in use**
   ```bash
   sudo netstat -tulpn | grep :5000
   # Kill the process using the port or change the port in server.py
   ```

3. **Containers not starting**
   ```bash
   docker-compose logs
   # Check the logs for specific error messages
   ```

4. **Python dependencies missing**
   ```bash
   pip3 install -r requirements.txt
   ```

### Log Locations

- Application logs: Terminal where `python3 server.py` is running
- Container logs: `docker-compose logs [container-name]`
- System logs: `/var/log/syslog`
- Nginx logs: `/var/log/nginx/`

## Security Considerations

### Production Deployment

1. **Change default credentials**
   - Edit `server.py` and update `ADMIN_USERNAME` and `ADMIN_PASSWORD_HASH`

2. **Use HTTPS**
   - Set up SSL certificates (Let's Encrypt recommended)
   - Configure Nginx reverse proxy

3. **Firewall configuration**
   - Only allow necessary ports
   - Consider VPN access for management

4. **Regular updates**
   - Keep Docker and system packages updated
   - Monitor for security updates

### Backup

```bash
# Backup configuration
tar -czf not-a-cpanel-backup-$(date +%Y%m%d).tar.gz \
    nginx-configs/ web-content/ docker-compose.yml server.py

# Backup to remote location
scp not-a-cpanel-backup-*.tar.gz user@backup-server:/backups/
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review logs for error messages
3. Create an issue on GitHub
4. Check the main README.md for additional information