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

class PostgreSQLManager:
    def __init__(self):
        self.postgres_user = "postgres"
        self.postgres_db = "postgres"
    
    def check_installation(self):
        """Check if PostgreSQL is installed"""
        result = self.run_command("which psql")
        if result['success']:
            version_result = self.run_command("psql --version")
            version = version_result['stdout'].split()[-1] if version_result['success'] else None
            return {
                'installed': True,
                'version': version
            }
        return {
            'installed': False,
            'version': None
        }
    
    def check_service_status(self):
        """Check if PostgreSQL service is running"""
        result = self.run_command("systemctl is-active postgresql")
        return {
            'running': result['success'] and result['stdout'].strip() == 'active'
        }
    
    def install_postgresql(self):
        """Install PostgreSQL server"""
        commands = [
            "apt update",
            "apt install -y postgresql postgresql-contrib",
            "systemctl start postgresql",
            "systemctl enable postgresql"
        ]
        
        results = []
        for cmd in commands:
            result = self.run_command(cmd)
            results.append(result)
            if not result['success']:
                return {
                    'success': False,
                    'error': f"Failed to execute: {cmd}",
                    'details': result
                }
        
        # Set up postgres user password
        setup_result = self.run_command(
            "sudo -u postgres psql -c \"ALTER USER postgres PASSWORD 'postgres';\""
        )
        
        return {
            'success': True,
            'message': 'PostgreSQL installed successfully',
            'setup_result': setup_result
        }
    
    def start_service(self):
        """Start PostgreSQL service"""
        result = self.run_command("systemctl start postgresql")
        return result
    
    def stop_service(self):
        """Stop PostgreSQL service"""
        result = self.run_command("systemctl stop postgresql")
        return result
    
    def restart_service(self):
        """Restart PostgreSQL service"""
        result = self.run_command("systemctl restart postgresql")
        return result
    
    def list_databases(self):
        """List all databases"""
        result = self.run_command(
            f"sudo -u postgres psql -c \"SELECT datname, pg_catalog.pg_get_userbyid(datdba) as owner, pg_size_pretty(pg_database_size(datname)) as size, datcollate as encoding FROM pg_database WHERE datistemplate = false;\" --csv"
        )
        
        if result['success']:
            lines = result['stdout'].strip().split('\n')
            if len(lines) > 1:  # Skip header
                databases = []
                for line in lines[1:]:
                    parts = line.split(',')
                    if len(parts) >= 4:
                        databases.append({
                            'name': parts[0].strip('"'),
                            'owner': parts[1].strip('"'),
                            'size': parts[2].strip('"'),
                            'encoding': parts[3].strip('"')
                        })
                return {
                    'success': True,
                    'databases': databases
                }
        
        return {
            'success': False,
            'error': 'Failed to list databases',
            'details': result
        }
    
    def create_database(self, db_name, owner=None):
        """Create a new database"""
        owner_clause = f"OWNER {owner}" if owner else ""
        result = self.run_command(
            f"sudo -u postgres createdb {db_name} {owner_clause}"
        )
        return result
    
    def drop_database(self, db_name):
        """Drop a database"""
        result = self.run_command(f"sudo -u postgres dropdb {db_name}")
        return result
    
    def list_users(self):
        """List all database users"""
        result = self.run_command(
            "sudo -u postgres psql -c \"SELECT usename, usesuper, usecreatedb, usecreaterole FROM pg_user;\" --csv"
        )
        
        if result['success']:
            lines = result['stdout'].strip().split('\n')
            if len(lines) > 1:  # Skip header
                users = []
                for line in lines[1:]:
                    parts = line.split(',')
                    if len(parts) >= 4:
                        users.append({
                            'username': parts[0].strip('"'),
                            'superuser': parts[1].strip('"').lower() == 't',
                            'createdb': parts[2].strip('"').lower() == 't',
                            'createrole': parts[3].strip('"').lower() == 't'
                        })
                return {
                    'success': True,
                    'users': users
                }
        
        return {
            'success': False,
            'error': 'Failed to list users',
            'details': result
        }
    
    def create_user(self, username, password, superuser=False):
        """Create a new database user"""
        superuser_clause = "SUPERUSER" if superuser else "NOSUPERUSER"
        result = self.run_command(
            f"sudo -u postgres psql -c \"CREATE USER {username} WITH PASSWORD '{password}' {superuser_clause};\""
        )
        return result
    
    def drop_user(self, username):
        """Drop a database user"""
        result = self.run_command(
            f"sudo -u postgres psql -c \"DROP USER {username};\""
        )
        return result
    
    def change_user_password(self, username, new_password):
        """Change user password"""
        result = self.run_command(
            f"sudo -u postgres psql -c \"ALTER USER {username} PASSWORD '{new_password}';\""
        )
        return result
    
    def execute_sql(self, database, query):
        """Execute SQL query"""
        # Escape single quotes in query
        escaped_query = query.replace("'", "''")
        
        result = self.run_command(
            f"sudo -u postgres psql -d {database} -c \"{escaped_query}\""
        )
        return result
    
    def run_command(self, command, shell=True):
        """Execute a shell command and return the result"""
        try:
            result = subprocess.run(
                command, 
                shell=shell, 
                capture_output=True, 
                text=True, 
                timeout=60
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

# Initialize managers
docker_manager = DockerManager()
postgres_manager = PostgreSQLManager()

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

# PostgreSQL Management Routes
@app.route('/api/postgresql/status')
@require_auth
def get_postgresql_status():
    """Get PostgreSQL installation and service status"""
    install_status = postgres_manager.check_installation()
    service_status = postgres_manager.check_service_status()
    
    return jsonify({
        'success': True,
        'installed': install_status['installed'],
        'version': install_status['version'],
        'running': service_status['running']
    })

@app.route('/api/postgresql/install', methods=['POST'])
@require_auth
def install_postgresql():
    """Install PostgreSQL server"""
    result = postgres_manager.install_postgresql()
    return jsonify(result)

@app.route('/api/postgresql/start', methods=['POST'])
@require_auth
def start_postgresql():
    """Start PostgreSQL service"""
    result = postgres_manager.start_service()
    return jsonify(result)

@app.route('/api/postgresql/stop', methods=['POST'])
@require_auth
def stop_postgresql():
    """Stop PostgreSQL service"""
    result = postgres_manager.stop_service()
    return jsonify(result)

@app.route('/api/postgresql/restart', methods=['POST'])
@require_auth
def restart_postgresql():
    """Restart PostgreSQL service"""
    result = postgres_manager.restart_service()
    return jsonify(result)

@app.route('/api/postgresql/databases')
@require_auth
def list_databases():
    """List all databases"""
    result = postgres_manager.list_databases()
    return jsonify(result)

@app.route('/api/postgresql/databases', methods=['POST'])
@require_auth
def create_database():
    """Create a new database"""
    data = request.get_json()
    db_name = data.get('name', '').strip()
    owner = data.get('owner', '').strip()
    
    if not db_name:
        return jsonify({
            'success': False,
            'error': 'Database name is required'
        }), 400
    
    result = postgres_manager.create_database(db_name, owner if owner else None)
    return jsonify(result)

@app.route('/api/postgresql/databases/<db_name>', methods=['DELETE'])
@require_auth
def drop_database(db_name):
    """Drop a database"""
    result = postgres_manager.drop_database(db_name)
    return jsonify(result)

@app.route('/api/postgresql/users')
@require_auth
def list_users():
    """List all database users"""
    result = postgres_manager.list_users()
    return jsonify(result)

@app.route('/api/postgresql/users', methods=['POST'])
@require_auth
def create_user():
    """Create a new database user"""
    data = request.get_json()
    username = data.get('username', '').strip()
    password = data.get('password', '')
    superuser = data.get('superuser', False)
    
    if not username or not password:
        return jsonify({
            'success': False,
            'error': 'Username and password are required'
        }), 400
    
    result = postgres_manager.create_user(username, password, superuser)
    return jsonify(result)

@app.route('/api/postgresql/users/<username>', methods=['DELETE'])
@require_auth
def drop_user(username):
    """Drop a database user"""
    result = postgres_manager.drop_user(username)
    return jsonify(result)

@app.route('/api/postgresql/users/<username>/password', methods=['POST'])
@require_auth
def change_user_password(username):
    """Change user password"""
    data = request.get_json()
    new_password = data.get('password', '')
    
    if not new_password:
        return jsonify({
            'success': False,
            'error': 'New password is required'
        }), 400
    
    result = postgres_manager.change_user_password(username, new_password)
    return jsonify(result)

@app.route('/api/postgresql/execute', methods=['POST'])
@require_auth
def execute_sql():
    """Execute SQL query"""
    data = request.get_json()
    database = data.get('database', '').strip()
    query = data.get('query', '').strip()
    
    if not database or not query:
        return jsonify({
            'success': False,
            'error': 'Database and query are required'
        }), 400
    
    result = postgres_manager.execute_sql(database, query)
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