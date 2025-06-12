#!/usr/bin/env python3
"""
Not a cPanel - Docker Container Management Server
A simple Flask server to manage Docker containers and Nginx instances
"""

import os
import json
import subprocess
import threading
import time
import hashlib
import secrets
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request, send_from_directory, session
from flask_cors import CORS
from functools import wraps

app = Flask(__name__)
CORS(app)

# Configuration
SERVER_IP = "4.221.197.153"
USERNAME = "bleedadmin"
DOCKER_COMPOSE_FILE = "docker-compose.yml"

# Authentication configuration
app.secret_key = secrets.token_hex(32)  # Generate a secure secret key
ADMIN_USERNAME = "admin"
ADMIN_PASSWORD_HASH = hashlib.sha256("docker123!".encode()).hexdigest()
SESSION_TIMEOUT = timedelta(hours=4)

# Store active sessions (in production, use Redis or database)
active_sessions = {}

def require_auth(f):
    """Decorator to require authentication for API endpoints"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({'success': False, 'error': 'Authentication required'}), 401
        
        token = auth_header.split(' ')[1]
        if token not in active_sessions:
            return jsonify({'success': False, 'error': 'Invalid or expired session'}), 401
        
        session_data = active_sessions[token]
        if datetime.now() > session_data['expires']:
            del active_sessions[token]
            return jsonify({'success': False, 'error': 'Session expired'}), 401
        
        # Extend session
        session_data['expires'] = datetime.now() + SESSION_TIMEOUT
        return f(*args, **kwargs)
    
    return decorated_function

def generate_session_token():
    """Generate a secure session token"""
    return secrets.token_urlsafe(32)

class DockerManager:
    def __init__(self):
        self.containers = []
        self.refresh_containers()
    
    def run_command(self, command, shell=True):
        """Execute a shell command and return the result"""
        try:
            result = subprocess.run(
                command, 
                shell=shell, 
                capture_output=True, 
                text=True, 
                timeout=30
            )
            return {
                'success': result.returncode == 0,
                'stdout': result.stdout.strip(),
                'stderr': result.stderr.strip(),
                'returncode': result.returncode
            }
        except subprocess.TimeoutExpired:
            return {
                'success': False,
                'stdout': '',
                'stderr': 'Command timed out',
                'returncode': -1
            }
        except Exception as e:
            return {
                'success': False,
                'stdout': '',
                'stderr': str(e),
                'returncode': -1
            }
    
    def refresh_containers(self):
        """Refresh the list of Docker containers"""
        result = self.run_command("docker ps -a --format json")
        
        if result['success'] and result['stdout']:
            self.containers = []
            for line in result['stdout'].split('\n'):
                if line.strip():
                    try:
                        container_data = json.loads(line)
                        self.containers.append({
                            'id': container_data.get('ID', ''),
                            'name': container_data.get('Names', ''),
                            'image': container_data.get('Image', ''),
                            'status': 'running' if container_data.get('State', '') == 'running' else 'stopped',
                            'ports': container_data.get('Ports', ''),
                            'created': container_data.get('CreatedAt', ''),
                            'command': container_data.get('Command', '')
                        })
                    except json.JSONDecodeError:
                        continue
        
        return self.containers
    
    def get_container_stats(self, container_id):
        """Get resource usage stats for a container"""
        result = self.run_command(f"docker stats {container_id} --no-stream --format json")
        
        if result['success'] and result['stdout']:
            try:
                stats = json.loads(result['stdout'])
                return {
                    'cpu': float(stats.get('CPUPerc', '0%').replace('%', '')),
                    'memory': stats.get('MemUsage', '0B / 0B'),
                    'network': stats.get('NetIO', '0B / 0B'),
                    'block_io': stats.get('BlockIO', '0B / 0B')
                }
            except (json.JSONDecodeError, ValueError):
                pass
        
        return {
            'cpu': 0.0,
            'memory': '0B / 0B',
            'network': '0B / 0B',
            'block_io': '0B / 0B'
        }
    
    def start_container(self, container_id):
        """Start a Docker container"""
        result = self.run_command(f"docker start {container_id}")
        return result
    
    def stop_container(self, container_id):
        """Stop a Docker container"""
        result = self.run_command(f"docker stop {container_id}")
        return result
    
    def restart_container(self, container_id):
        """Restart a Docker container"""
        result = self.run_command(f"docker restart {container_id}")
        return result
    
    def get_container_logs(self, container_id, lines=100):
        """Get logs from a Docker container"""
        result = self.run_command(f"docker logs --tail {lines} {container_id}")
        return result
    
    def exec_command_in_container(self, container_id, command):
        """Execute a command inside a Docker container"""
        result = self.run_command(f"docker exec {container_id} {command}")
        return result
    
    def get_nginx_config(self, container_id):
        """Get Nginx configuration from a container"""
        result = self.run_command(f"docker exec {container_id} cat /etc/nginx/nginx.conf")
        return result
    
    def set_nginx_config(self, container_id, config_content):
        """Set Nginx configuration in a container"""
        # Write config to temporary file
        temp_file = f"/tmp/nginx_config_{container_id}.conf"
        try:
            with open(temp_file, 'w') as f:
                f.write(config_content)
            
            # Copy to container
            copy_result = self.run_command(f"docker cp {temp_file} {container_id}:/etc/nginx/nginx.conf")
            
            # Clean up temp file
            os.remove(temp_file)
            
            if copy_result['success']:
                # Test configuration
                test_result = self.run_command(f"docker exec {container_id} nginx -t")
                if test_result['success']:
                    # Reload nginx
                    reload_result = self.run_command(f"docker exec {container_id} nginx -s reload")
                    return reload_result
                else:
                    return test_result
            else:
                return copy_result
                
        except Exception as e:
            return {
                'success': False,
                'stdout': '',
                'stderr': str(e),
                'returncode': -1
            }
    
    def reload_nginx(self, container_id):
        """Reload Nginx in a container"""
        result = self.run_command(f"docker exec {container_id} nginx -s reload")
        return result
    
    def test_nginx_config(self, container_id):
        """Test Nginx configuration in a container"""
        result = self.run_command(f"docker exec {container_id} nginx -t")
        return result

# Initialize Docker manager
docker_manager = DockerManager()

# Routes
@app.route('/')
def index():
    """Serve the main application"""
    return send_from_directory('.', 'index.html')

@app.route('/<path:filename>')
def serve_static(filename):
    """Serve static files"""
    return send_from_directory('.', filename)

@app.route('/api/auth/login', methods=['POST'])
def login():
    """Authenticate user and create session"""
    data = request.get_json()
    username = data.get('username', '').strip()
    password = data.get('password', '')
    
    if not username or not password:
        return jsonify({
            'success': False,
            'error': 'Username and password are required'
        }), 400
    
    # Hash the provided password
    password_hash = hashlib.sha256(password.encode()).hexdigest()
    
    # Check credentials
    if username == ADMIN_USERNAME and password_hash == ADMIN_PASSWORD_HASH:
        # Generate session token
        token = generate_session_token()
        
        # Store session
        active_sessions[token] = {
            'username': username,
            'created': datetime.now(),
            'expires': datetime.now() + SESSION_TIMEOUT,
            'ip': request.remote_addr
        }
        
        return jsonify({
            'success': True,
            'token': token,
            'username': username,
            'expires': (datetime.now() + SESSION_TIMEOUT).isoformat()
        })
    else:
        # Add a small delay to prevent brute force attacks
        time.sleep(1)
        return jsonify({
            'success': False,
            'error': 'Invalid username or password'
        }), 401

@app.route('/api/auth/logout', methods=['POST'])
def logout():
    """Logout user and invalidate session"""
    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.startswith('Bearer '):
        token = auth_header.split(' ')[1]
        if token in active_sessions:
            del active_sessions[token]
    
    return jsonify({'success': True, 'message': 'Logged out successfully'})

@app.route('/api/auth/verify', methods=['GET'])
@require_auth
def verify_auth():
    """Verify if current session is valid"""
    return jsonify({'success': True, 'authenticated': True})

@app.route('/api/containers')
@require_auth
def get_containers():
    """Get list of all containers"""
    containers = docker_manager.refresh_containers()
    
    # Add stats for running containers
    for container in containers:
        if container['status'] == 'running':
            stats = docker_manager.get_container_stats(container['id'])
            container.update(stats)
    
    return jsonify({
        'success': True,
        'containers': containers,
        'server_info': {
            'ip': SERVER_IP,
            'username': USERNAME,
            'total_containers': len(containers),
            'running_containers': len([c for c in containers if c['status'] == 'running'])
        }
    })

@app.route('/api/containers/<container_id>/start', methods=['POST'])
@require_auth
def start_container(container_id):
    """Start a container"""
    result = docker_manager.start_container(container_id)
    return jsonify(result)

@app.route('/api/containers/<container_id>/stop', methods=['POST'])
@require_auth
def stop_container(container_id):
    """Stop a container"""
    result = docker_manager.stop_container(container_id)
    return jsonify(result)

@app.route('/api/containers/<container_id>/restart', methods=['POST'])
@require_auth
def restart_container(container_id):
    """Restart a container"""
    result = docker_manager.restart_container(container_id)
    return jsonify(result)

@app.route('/api/containers/<container_id>/logs')
@require_auth
def get_container_logs(container_id):
    """Get container logs"""
    lines = request.args.get('lines', 100, type=int)
    result = docker_manager.get_container_logs(container_id, lines)
    return jsonify(result)

@app.route('/api/containers/<container_id>/exec', methods=['POST'])
@require_auth
def exec_in_container(container_id):
    """Execute command in container"""
    data = request.get_json()
    command = data.get('command', '')
    
    if not command:
        return jsonify({
            'success': False,
            'stderr': 'No command provided'
        })
    
    result = docker_manager.exec_command_in_container(container_id, command)
    return jsonify(result)

@app.route('/api/containers/<container_id>/nginx/config')
@require_auth
def get_nginx_config(container_id):
    """Get Nginx configuration"""
    result = docker_manager.get_nginx_config(container_id)
    return jsonify(result)

@app.route('/api/containers/<container_id>/nginx/config', methods=['POST'])
@require_auth
def set_nginx_config(container_id):
    """Set Nginx configuration"""
    data = request.get_json()
    config_content = data.get('config', '')
    
    if not config_content:
        return jsonify({
            'success': False,
            'stderr': 'No configuration content provided'
        })
    
    result = docker_manager.set_nginx_config(container_id, config_content)
    return jsonify(result)

@app.route('/api/containers/<container_id>/nginx/reload', methods=['POST'])
@require_auth
def reload_nginx(container_id):
    """Reload Nginx in container"""
    result = docker_manager.reload_nginx(container_id)
    return jsonify(result)

@app.route('/api/containers/<container_id>/nginx/test', methods=['POST'])
@require_auth
def test_nginx_config(container_id):
    """Test Nginx configuration"""
    result = docker_manager.test_nginx_config(container_id)
    return jsonify(result)

@app.route('/api/system/info')
@require_auth
def get_system_info():
    """Get system information"""
    # Get Docker info
    docker_info = docker_manager.run_command("docker info --format json")
    
    # Get system info
    system_info = {
        'hostname': docker_manager.run_command("hostname")['stdout'],
        'uptime': docker_manager.run_command("uptime")['stdout'],
        'disk_usage': docker_manager.run_command("df -h /")['stdout'],
        'memory_info': docker_manager.run_command("free -h")['stdout'],
        'docker_version': docker_manager.run_command("docker --version")['stdout']
    }
    
    return jsonify({
        'success': True,
        'system_info': system_info,
        'docker_info': docker_info['stdout'] if docker_info['success'] else None
    })

@app.route('/api/system/command', methods=['POST'])
@require_auth
def execute_system_command():
    """Execute a system command"""
    data = request.get_json()
    command = data.get('command', '')
    
    if not command:
        return jsonify({
            'success': False,
            'stderr': 'No command provided'
        })
    
    # Security: Only allow certain safe commands
    allowed_commands = [
        'docker', 'ls', 'pwd', 'whoami', 'date', 'uptime', 'df', 'free', 
        'ps', 'top', 'htop', 'netstat', 'ss', 'systemctl'
    ]
    
    command_parts = command.split()
    if not command_parts or command_parts[0] not in allowed_commands:
        return jsonify({
            'success': False,
            'stderr': f'Command not allowed: {command_parts[0] if command_parts else "empty"}'
        })
    
    result = docker_manager.run_command(command)
    return jsonify(result)

if __name__ == '__main__':
    print(f"Starting Not a cPanel server...")
    print(f"Server: {SERVER_IP}")
    print(f"User: {USERNAME}")
    print(f"Access the control panel at: http://localhost:5000")
    
    # Create docker-compose.yml if it doesn't exist
    if not os.path.exists(DOCKER_COMPOSE_FILE):
        compose_content = """version: '3.8'
services:
  nginx-web-01:
    image: nginx:latest
    ports:
      - "8081:80"
    volumes:
      - ./nginx-configs/web-01:/etc/nginx/conf.d
    restart: unless-stopped

  nginx-web-02:
    image: nginx:latest
    ports:
      - "8082:80"
    volumes:
      - ./nginx-configs/web-02:/etc/nginx/conf.d
    restart: unless-stopped

  nginx-web-03:
    image: nginx:latest
    ports:
      - "8083:80"
    volumes:
      - ./nginx-configs/web-03:/etc/nginx/conf.d
    restart: unless-stopped

  nginx-web-04:
    image: nginx:latest
    ports:
      - "8084:80"
    volumes:
      - ./nginx-configs/web-04:/etc/nginx/conf.d
    restart: unless-stopped

  nginx-web-05:
    image: nginx:latest
    ports:
      - "8085:80"
    volumes:
      - ./nginx-configs/web-05:/etc/nginx/conf.d
    restart: unless-stopped

  nginx-api-01:
    image: nginx:latest
    ports:
      - "8086:80"
    volumes:
      - ./nginx-configs/api-01:/etc/nginx/conf.d
    restart: unless-stopped

  nginx-api-02:
    image: nginx:latest
    ports:
      - "8087:80"
    volumes:
      - ./nginx-configs/api-02:/etc/nginx/conf.d
    restart: unless-stopped

  nginx-lb-01:
    image: nginx:latest
    ports:
      - "8088:80"
    volumes:
      - ./nginx-configs/lb-01:/etc/nginx/conf.d
    restart: unless-stopped

  nginx-static-01:
    image: nginx:latest
    ports:
      - "8089:80"
    volumes:
      - ./nginx-configs/static-01:/etc/nginx/conf.d
    restart: unless-stopped

  nginx-proxy-01:
    image: nginx:latest
    ports:
      - "8090:80"
    volumes:
      - ./nginx-configs/proxy-01:/etc/nginx/conf.d
    restart: unless-stopped
"""
        with open(DOCKER_COMPOSE_FILE, 'w') as f:
            f.write(compose_content)
        print(f"Created {DOCKER_COMPOSE_FILE}")
    
    app.run(host='0.0.0.0', port=5000, debug=True)