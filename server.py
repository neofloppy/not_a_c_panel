#!/usr/bin/env python3

"""
Not a cPanel - Docker Container Management System
A web-based control panel for managing Docker containers
"""

import os
import json
import subprocess
import threading
import time
import hashlib
import secrets
import psycopg2
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request, send_from_directory, session
from flask_cors import CORS
from functools import wraps

app = Flask(__name__)
CORS(app)

# Configuration - These will be set during installation
SERVER_IP = "localhost"  # Default fallback
USERNAME = "user"        # Default fallback

# PostgreSQL Configuration
DB_CONFIG = {
    'host': 'localhost',
    'database': 'notacpanel',
    'user': 'notacpanel',
    'password': 'notacpanel123',
    'port': 5432
}

# Try to load configuration from config file
CONFIG_FILE = "config.py"
if os.path.exists(CONFIG_FILE):
    try:
        config_globals = {}
        exec(open(CONFIG_FILE).read(), config_globals)
        
        # Update variables if they exist in config
        if 'SERVER_IP' in config_globals:
            SERVER_IP = config_globals['SERVER_IP']
        if 'USERNAME' in config_globals:
            USERNAME = config_globals['USERNAME']
        if 'ADMIN_PASSWORD' in config_globals:
            ADMIN_PASSWORD = config_globals['ADMIN_PASSWORD']
            
    except Exception as e:
        print(f"Warning: Could not load config file: {e}")
        print(f"Using default values: SERVER_IP={SERVER_IP}, USERNAME={USERNAME}")

# Authentication configuration
app.secret_key = secrets.token_hex(32)  # Generate a secure secret key
ADMIN_USERNAME = "admin"

# Default password, will be overridden by config.py if it exists
if 'ADMIN_PASSWORD' not in locals():
    ADMIN_PASSWORD = "docker123!"

# Generate password hash
ADMIN_PASSWORD_HASH = hashlib.sha256(ADMIN_PASSWORD.encode()).hexdigest()
SESSION_TIMEOUT = timedelta(hours=4)

# Store active sessions (in production, use Redis or database)
active_sessions = {}

# Database connection and initialization
def get_db_connection():
    """Get PostgreSQL database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        return None

def init_database():
    """Initialize database tables"""
    conn = get_db_connection()
    if not conn:
        print("Warning: Could not connect to database")
        return False
    
    try:
        cursor = conn.cursor()
        
        # Create containers table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS containers (
                id SERIAL PRIMARY KEY,
                container_id VARCHAR(64) UNIQUE NOT NULL,
                name VARCHAR(100) NOT NULL,
                image VARCHAR(200) NOT NULL,
                status VARCHAR(20) NOT NULL,
                ports JSONB,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create container_configs table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS container_configs (
                id SERIAL PRIMARY KEY,
                container_id VARCHAR(64) NOT NULL,
                config_type VARCHAR(50) NOT NULL,
                config_content TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Create system_logs table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS system_logs (
                id SERIAL PRIMARY KEY,
                level VARCHAR(20) NOT NULL,
                message TEXT NOT NULL,
                details JSONB,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        cursor.close()
        conn.close()
        print("Database initialized successfully")
        return True
        
    except Exception as e:
        print(f"Database initialization error: {e}")
        if conn:
            conn.close()
        return False

def require_auth(f):
    """Decorator to require authentication for API endpoints"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({'success': False, 'error': 'Authentication required'}), 401
        
        user_id = session['user_id']
        if user_id not in active_sessions:
            session.clear()
            return jsonify({'success': False, 'error': 'Session expired'}), 401
        
        # Check session timeout
        if datetime.now() - active_sessions[user_id]['last_activity'] > SESSION_TIMEOUT:
            del active_sessions[user_id]
            session.clear()
            return jsonify({'success': False, 'error': 'Session expired'}), 401
        
        # Update last activity
        active_sessions[user_id]['last_activity'] = datetime.now()
        
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
            if shell:
                result = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=30)
            else:
                result = subprocess.run(command, capture_output=True, text=True, timeout=30)
            
            return {
                'success': result.returncode == 0,
                'stdout': result.stdout,
                'stderr': result.stderr,
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
        self.containers = []
        
        # Get all containers (running and stopped)
        result = self.run_command("docker ps -a --format json")
        
        if result['success'] and result['stdout']:
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
        <p><a href="http://{SERVER_IP}:5000" target="_blank">🔗 Access Control Panel</a></p>
    </div>
</body>
</html>"""
        
        with open(f'{content_dir}/index.html', 'w') as f:
            f.write(html_content)
    
    def start_container(self, container_id):
        """Start a Docker container"""
        result = self.run_command(f"docker start {container_id}")
        if result['success']:
            self.refresh_containers()
        return result
    
    def stop_container(self, container_id):
        """Stop a Docker container"""
        result = self.run_command(f"docker stop {container_id}")
        if result['success']:
            self.refresh_containers()
        return result
    
    def restart_container(self, container_id):
        """Restart a Docker container"""
        result = self.run_command(f"docker restart {container_id}")
        if result['success']:
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

# Routes
@app.route('/')
def index():
    """Serve the main page"""
    return send_from_directory('.', 'index.html')

@app.route('/<path:filename>')
def serve_static(filename):
    """Serve static files"""
    return send_from_directory('.', filename)

@app.route('/api/login', methods=['POST'])
def login():
    """Handle user login"""
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'success': False, 'error': 'Username and password required'}), 400
    
    # Check credentials
    password_hash = hashlib.sha256(password.encode()).hexdigest()
    
    if username == ADMIN_USERNAME and password_hash == ADMIN_PASSWORD_HASH:
        # Generate session
        session_token = generate_session_token()
        session['user_id'] = session_token
        
        # Store session info
        active_sessions[session_token] = {
            'username': username,
            'login_time': datetime.now(),
            'last_activity': datetime.now()
        }
        
        return jsonify({
            'success': True,
            'message': 'Login successful',
            'user': username
        })
    else:
        return jsonify({'success': False, 'error': 'Invalid credentials'}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    """Handle user logout"""
    if 'user_id' in session:
        user_id = session['user_id']
        if user_id in active_sessions:
            del active_sessions[user_id]
        session.clear()
    
    return jsonify({'success': True, 'message': 'Logged out successfully'})

@app.route('/api/containers')
@require_auth
def get_containers():
    """Get list of all containers"""
    docker_manager.refresh_containers()
    return jsonify({
        'success': True,
        'containers': docker_manager.containers
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

@app.route('/api/containers/<container_id>/start', methods=['POST'])
@require_auth
def start_container(container_id):
    """Start a container"""
    result = docker_manager.start_container(container_id)
    
    if result['success']:
        return jsonify({
            'success': True,
            'message': f'Container "{container_id}" started successfully'
        })
    else:
        return jsonify(result), 400

@app.route('/api/containers/<container_id>/stop', methods=['POST'])
@require_auth
def stop_container(container_id):
    """Stop a container"""
    result = docker_manager.stop_container(container_id)
    
    if result['success']:
        return jsonify({
            'success': True,
            'message': f'Container "{container_id}" stopped successfully'
        })
    else:
        return jsonify(result), 400

@app.route('/api/containers/<container_id>/restart', methods=['POST'])
@require_auth
def restart_container(container_id):
    """Restart a container"""
    result = docker_manager.restart_container(container_id)
    
    if result['success']:
        return jsonify({
            'success': True,
            'message': f'Container "{container_id}" restarted successfully'
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

@app.route('/api/postgresql/execute', methods=['POST'])
@require_auth
def execute_postgresql():
    """Execute PostgreSQL query"""
    data = request.get_json()
    database = data.get('database')
    query = data.get('query')
    
    if not database or not query:
        return jsonify({
            'success': False,
            'error': 'Database and query are required'
        }), 400
    
    # Execute query using psycopg2
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({
                'success': False,
                'error': 'Could not connect to database'
            }), 500
        
        cursor = conn.cursor()
        cursor.execute(query)
        
        if query.strip().upper().startswith('SELECT'):
            results = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description]
            data = [dict(zip(columns, row)) for row in results]
            result = {
                'success': True,
                'data': data,
                'columns': columns,
                'row_count': len(results)
            }
        else:
            conn.commit()
            result = {
                'success': True,
                'message': f'Query executed successfully. Rows affected: {cursor.rowcount}',
                'rows_affected': cursor.rowcount
            }
        
        cursor.close()
        conn.close()
        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

# Initialize Docker manager
docker_manager = DockerManager()

if __name__ == '__main__':
    print("Starting Not a cPanel server...")
    print(f"Server: {SERVER_IP}")
    print(f"User: {USERNAME}")
    print(f"Access the control panel at: http://{SERVER_IP}:5000")
    
    # Initialize database
    print("Initializing database...")
    if init_database():
        print("Database ready")
    else:
        print("Warning: Database initialization failed, some features may not work")
    
    # Initialize Docker manager
    print("Initializing Docker manager...")
    print(f"Found {len(docker_manager.containers)} existing containers")
    
    app.run(host='0.0.0.0', port=5000, debug=True)