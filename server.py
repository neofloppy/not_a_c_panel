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

# Configuration - These will be set during installation
SERVER_IP = "localhost"  # Default fallback
USERNAME = "user"        # Default fallback
DOCKER_COMPOSE_FILE = "docker-compose.yml"

# Try to load configuration from config file
import os
CONFIG_FILE = "config.py"
if os.path.exists(CONFIG_FILE):
    try:
        exec(open(CONFIG_FILE).read())
    except Exception as e:
        print(f"Warning: Could not load config file: {e}")

# Authentication configuration
app.secret_key = secrets.token_hex(32)  # Generate a secure secret key
ADMIN_USERNAME = "admin"

# Default password, will be overridden by config.py if it exists
ADMIN_PASSWORD = "docker123!"
if 'ADMIN_PASSWORD' in locals():
    ADMIN_PASSWORD_HASH = hashlib.sha256(ADMIN_PASSWORD.encode()).hexdigest()
else:
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
        self.compose_file = "docker-compose.yml"
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
                        # Parse ports information
                        ports_raw = container_data.get('Ports', '')
                        ports = self._parse_ports(ports_raw)
                        
                        self.containers.append({
                            'id': container_data.get('ID', ''),
                            'name': container_data.get('Names', ''),
                            'image': container_data.get('Image', ''),
                            'status': 'running' if container_data.get('State', '') == 'running' else 'stopped',
                            'ports': ports_raw,
                            'parsed_ports': ports,
                            'created': container_data.get('CreatedAt', ''),
                            'command': container_data.get('Command', ''),
                            'size': container_data.get('Size', ''),
                            'networks': container_data.get('Networks', ''),
                            'mounts': container_data.get('Mounts', '')
                        })
                    except json.JSONDecodeError:
                        continue
        
        return self.containers
    
    def _parse_ports(self, ports_str):
        """Parse Docker ports string into structured format"""
        if not ports_str:
            return []
        
        ports = []
        # Example: "0.0.0.0:8001->80/tcp, 0.0.0.0:8002->80/tcp"
        port_mappings = ports_str.split(', ')
        
        for mapping in port_mappings:
            if '->' in mapping:
                try:
                    external, internal = mapping.split('->')
                    external_parts = external.split(':')
                    if len(external_parts) == 2:
                        host_ip = external_parts[0]
                        host_port = external_parts[1]
                    else:
                        host_ip = '0.0.0.0'
                        host_port = external_parts[0]
                    
                    internal_parts = internal.split('/')
                    container_port = internal_parts[0]
                    protocol = internal_parts[1] if len(internal_parts) > 1 else 'tcp'
                    
                    ports.append({
                        'host_ip': host_ip,
                        'host_port': host_port,
                        'container_port': container_port,
                        'protocol': protocol
                    })
                except:
                    continue
        
        return ports
    
    def get_available_port(self, start_port=8001):
        """Find the next available port starting from start_port"""
        used_ports = set()
        
        # Get ports from existing containers
        for container in self.containers:
            for port in container.get('parsed_ports', []):
                try:
                    used_ports.add(int(port['host_port']))
                except:
                    continue
        
        # Find next available port
        port = start_port
        while port in used_ports:
            port += 1
        
        return port
    
    def create_container(self, name, image="nginx:alpine", port=None, volumes=None, environment=None):
        """Create a new Docker container"""
        if not name:
            return {
                'success': False,
                'error': 'Container name is required'
            }
        
        # Check if container name already exists
        existing_names = [c['name'] for c in self.containers]
        if name in existing_names:
            return {
                'success': False,
                'error': f'Container with name "{name}" already exists'
            }
        
        # Get available port if not specified
        if port is None:
            port = self.get_available_port()
        
        # Build docker run command
        cmd_parts = ['docker', 'run', '-d', '--name', name]
        
        # Add port mapping
        cmd_parts.extend(['-p', f'{port}:80'])
        
        # Add volumes
        if volumes:
            for volume in volumes:
                cmd_parts.extend(['-v', volume])
        else:
            # Default nginx config volume
            config_dir = f'./nginx-configs/{name}'
            content_dir = f'./web-content/{name}'
            os.makedirs(config_dir, exist_ok=True)
            os.makedirs(content_dir, exist_ok=True)
            cmd_parts.extend(['-v', f'{config_dir}:/etc/nginx/conf.d'])
            cmd_parts.extend(['-v', f'{content_dir}:/usr/share/nginx/html'])
        
        # Add environment variables
        if environment:
            for env_var in environment:
                cmd_parts.extend(['-e', env_var])
        
        # Add restart policy
        cmd_parts.extend(['--restart', 'unless-stopped'])
        
        # Add image
        cmd_parts.append(image)
        
        # Execute command
        result = self.run_command(' '.join(cmd_parts))
        
        if result['success']:
            # Create default nginx config if it's an nginx container
            if 'nginx' in image.lower():
                self._create_default_nginx_config(name, port)
            
            # Refresh container list
            self.refresh_containers()
        
        return result
    
    def remove_container(self, container_id, force=False, remove_volumes=False):
        """Remove a Docker container"""
        # Stop container first if it's running
        container = self.get_container_by_id(container_id)
        if not container:
            return {
                'success': False,
                'error': 'Container not found'
            }
        
        if container['status'] == 'running':
            stop_result = self.stop_container(container_id)
            if not stop_result['success'] and not force:
                return {
                    'success': False,
                    'error': f'Failed to stop container: {stop_result["stderr"]}'
                }
        
        # Remove container
        cmd = f'docker rm {container_id}'
        if force:
            cmd = f'docker rm -f {container_id}'
        
        result = self.run_command(cmd)
        
        if result['success']:
            # Optionally remove associated volumes/configs
            if remove_volumes:
                container_name = container['name']
                config_dir = f'./nginx-configs/{container_name}'
                content_dir = f'./web-content/{container_name}'
                
                try:
                    import shutil
                    if os.path.exists(config_dir):
                        shutil.rmtree(config_dir)
                    if os.path.exists(content_dir):
                        shutil.rmtree(content_dir)
                except Exception as e:
                    result['warning'] = f'Container removed but failed to clean up directories: {str(e)}'
            
            # Refresh container list
            self.refresh_containers()
        
        return result
    
    def get_container_by_id(self, container_id):
        """Get container by ID or name"""
        for container in self.containers:
            if container['id'].startswith(container_id) or container['name'] == container_id:
                return container
        return None
    
    def _create_default_nginx_config(self, container_name, port):
        """Create default nginx configuration for a new container"""
        config_dir = f'./nginx-configs/{container_name}'
        content_dir = f'./web-content/{container_name}'
        
        # Create directories
        os.makedirs(config_dir, exist_ok=True)
        os.makedirs(content_dir, exist_ok=True)
        
        # Create default nginx config
        config_content = f"""server {{
    listen 80;
    server_name localhost;
    
    location / {{
        root /usr/share/nginx/html;
        index index.html index.htm;
    }}
    
    # Health check endpoint
    location /health {{
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }}
    
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {{
        root /usr/share/nginx/html;
    }}
}}"""
        
        with open(f'{config_dir}/default.conf', 'w') as f:
            f.write(config_content)
        
        # Create default index.html
        html_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>{container_name} - Not a cPanel</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; background: #f4f4f4; }}
        .container {{ background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        h1 {{ color: #333; }}
        .status {{ color: #28a745; font-weight: bold; }}
        .info {{ background: #e9ecef; padding: 15px; border-radius: 4px; margin: 20px 0; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳 Container: {container_name}</h1>
        <p class="status">✅ Container is running successfully!</p>
        <div class="info">
            <h3>Container Information:</h3>
            <ul>
                <li><strong>Container Name:</strong> {container_name}</li>
                <li><strong>Port:</strong> {port}</li>
                <li><strong>Service Type:</strong> Nginx Web Server</li>
                <li><strong>Status:</strong> Active</li>
                <li><strong>Managed by:</strong> Not a cPanel</li>
            </ul>
        </div>
        <p>This container is managed by the <strong>Not a cPanel</strong> control panel.</p>
        <p><a href="http://localhost:5000" target="_blank">🔗 Access Control Panel</a></p>
    </div>
</body>
</html>"""
        
        with open(f'{content_dir}/index.html', 'w') as f:
            f.write(html_content)
    
    def get_docker_images(self):
        """Get list of available Docker images"""
        result = self.run_command("docker images --format json")
        
        images = []
        if result['success'] and result['stdout']:
            for line in result['stdout'].split('\n'):
                if line.strip():
                    try:
                        image_data = json.loads(line)
                        images.append({
                            'repository': image_data.get('Repository', ''),
                            'tag': image_data.get('Tag', ''),
                            'id': image_data.get('ID', ''),
                            'created': image_data.get('CreatedAt', ''),
                            'size': image_data.get('Size', '')
                        })
                    except json.JSONDecodeError:
                        continue
        
        return {
            'success': True,
            'images': images
        }
    
    def pull_image(self, image_name):
        """Pull a Docker image"""
        result = self.run_command(f"docker pull {image_name}")
        return result
    
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

@app.route('/api/containers', methods=['POST'])
@require_auth
def create_container():
    """Create a new container"""
    data = request.get_json()
    
    name = data.get('name', '').strip()
    image = data.get('image', 'nginx:alpine').strip()
    port = data.get('port')
    volumes = data.get('volumes', [])
    environment = data.get('environment', [])
    
    if not name:
        return jsonify({
            'success': False,
            'error': 'Container name is required'
        }), 400
    
    # Validate port if provided
    if port is not None:
        try:
            port = int(port)
            if port < 1 or port > 65535:
                return jsonify({
                    'success': False,
                    'error': 'Port must be between 1 and 65535'
                }), 400
        except ValueError:
            return jsonify({
                'success': False,
                'error': 'Port must be a valid number'
            }), 400
    
    result = docker_manager.create_container(
        name=name,
        image=image,
        port=port,
        volumes=volumes,
        environment=environment
    )
    
    if result['success']:
        return jsonify({
            'success': True,
            'message': f'Container "{name}" created successfully',
            'container_id': result['stdout'][:12] if result['stdout'] else None
        })
    else:
        return jsonify(result), 400

@app.route('/api/containers/<container_id>', methods=['DELETE'])
@require_auth
def remove_container(container_id):
    """Remove a container"""
    force = request.args.get('force', 'false').lower() == 'true'
    remove_volumes = request.args.get('remove_volumes', 'false').lower() == 'true'
    
    result = docker_manager.remove_container(
        container_id=container_id,
        force=force,
        remove_volumes=remove_volumes
    )
    
    if result['success']:
        message = f'Container "{container_id}" removed successfully'
        if 'warning' in result:
            message += f' (Warning: {result["warning"]})'
        
        return jsonify({
            'success': True,
            'message': message
        })
    else:
        return jsonify(result), 400

@app.route('/api/images')
@require_auth
def get_images():
    """Get list of available Docker images"""
    result = docker_manager.get_docker_images()
    return jsonify(result)

@app.route('/api/images/pull', methods=['POST'])
@require_auth
def pull_image():
    """Pull a Docker image"""
    data = request.get_json()
    image_name = data.get('image', '').strip()
    
    if not image_name:
        return jsonify({
            'success': False,
            'error': 'Image name is required'
        }), 400
    
    result = docker_manager.pull_image(image_name)
    
    if result['success']:
        return jsonify({
            'success': True,
            'message': f'Image "{image_name}" pulled successfully',
            'output': result['stdout']
        })
    else:
        return jsonify(result), 400

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