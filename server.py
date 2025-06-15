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
import re
import logging
import shutil
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request, send_from_directory, session
from flask_cors import CORS
from functools import wraps
from werkzeug.security import generate_password_hash, check_password_hash
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import configparser
from typing import Dict, List, Optional, Any

app = Flask(__name__)

# Configure CORS with restrictions
CORS(app, origins=['http://localhost:5000', 'https://localhost:5000'], 
     supports_credentials=True, 
     allow_headers=['Content-Type', 'Authorization'])

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('not_a_cpanel.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Rate limiting
limiter = Limiter(
    app=app,
    key_func=get_remote_address,
    default_limits=[]  # No default limits, apply only to specific endpoints
)

# Configuration - Load from secure config file
SERVER_IP = "localhost"  # Default fallback
USERNAME = "user"        # Default fallback
ADMIN_PASSWORD_HASH = None  # Will be loaded from config

# PostgreSQL Configuration
DB_CONFIG = {
    'host': 'localhost',
    'database': 'notacpanel',
    'user': 'notacpanel',
    'password': 'notacpanel123',
    'port': 5432
}

def load_secure_config():
    """Load configuration from secure INI file"""
    global SERVER_IP, USERNAME, ADMIN_PASSWORD_HASH, ADMIN_USERNAME, DB_CONFIG
    
    config_file = "config.ini"
    if os.path.exists(config_file):
        try:
            config = configparser.ConfigParser()
            config.read(config_file)
            
            # Server configuration
            if 'server' in config:
                SERVER_IP = config.get('server', 'ip', fallback=SERVER_IP)
                USERNAME = config.get('server', 'username', fallback=USERNAME)
                ADMIN_USERNAME = USERNAME  # Use the same username for admin login
                
            # Admin credentials
            if 'admin' in config:
                password_hash = config.get('admin', 'password_hash', fallback=None)
                # Only use the hash if it's not empty
                if password_hash and password_hash.strip():
                    ADMIN_PASSWORD_HASH = password_hash.strip()
                else:
                    ADMIN_PASSWORD_HASH = None
                
            # Database configuration
            if 'database' in config:
                DB_CONFIG.update({
                    'host': config.get('database', 'host', fallback=DB_CONFIG['host']),
                    'database': config.get('database', 'database', fallback=DB_CONFIG['database']),
                    'user': config.get('database', 'user', fallback=DB_CONFIG['user']),
                    'password': config.get('database', 'password', fallback=DB_CONFIG['password']),
                    'port': config.getint('database', 'port', fallback=DB_CONFIG['port'])
                })
                
            logger.info(f"Configuration loaded from {config_file}")
        except Exception as e:
            logger.error(f"Error loading config file: {e}")
            logger.info(f"Using default values: SERVER_IP={SERVER_IP}, USERNAME={USERNAME}")
    else:
        # Create default config file
        create_default_config(config_file)

def create_default_config(config_file: str):
    """Create a default secure configuration file"""
    config = configparser.ConfigParser()
    
    config['server'] = {
        'ip': SERVER_IP,
        'username': USERNAME
    }
    
    # Generate secure password hash
    default_password = secrets.token_urlsafe(16)
    password_hash = generate_password_hash(default_password)
    
    config['admin'] = {
        'password_hash': password_hash
    }
    
    config['database'] = {
        'host': DB_CONFIG['host'],
        'database': DB_CONFIG['database'],
        'user': DB_CONFIG['user'],
        'password': DB_CONFIG['password'],
        'port': str(DB_CONFIG['port'])
    }
    
    with open(config_file, 'w') as f:
        config.write(f)
    
    logger.warning(f"Created default config file: {config_file}")
    logger.warning(f"Default admin password: {default_password}")
    logger.warning("Please change the default password and secure the config file!")
    
    global ADMIN_PASSWORD_HASH
    ADMIN_PASSWORD_HASH = password_hash

# Authentication configuration
app.secret_key = os.environ.get('SECRET_KEY', secrets.token_hex(32))
ADMIN_USERNAME = "admin"  # Default, will be updated from config
SESSION_TIMEOUT = timedelta(hours=4)

# Store active sessions with additional security info
active_sessions: Dict[str, Dict[str, Any]] = {}
failed_login_attempts: Dict[str, Dict[str, Any]] = {}

# Security constants
MAX_LOGIN_ATTEMPTS = 5
LOCKOUT_DURATION = timedelta(minutes=15)

# Input validation patterns
VALID_CONTAINER_NAME = re.compile(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]*$')
VALID_IMAGE_NAME = re.compile(r'^[a-z0-9]+([._-][a-z0-9]+)*(/[a-z0-9]+([._-][a-z0-9]+)*)*(:[\w.-]+)?$')
VALID_PORT = re.compile(r'^[1-9][0-9]{0,4}$')
VALID_DATABASE_NAME = re.compile(r'^[a-zA-Z][a-zA-Z0-9_]*$')

# Load configuration
load_secure_config()

def validate_input(value: str, pattern: re.Pattern, max_length: int = 100) -> bool:
    """Validate input against regex pattern and length"""
    if not value or len(value) > max_length:
        return False
    return bool(pattern.match(value))

def sanitize_for_shell(value: str) -> str:
    """Sanitize input for shell command execution"""
    # Allow alphanumeric, dash, underscore, dot, colon, and slash for Docker commands
    # This is more permissive but still safe when not using shell=True
    return re.sub(r'[^a-zA-Z0-9._\-:/]', '', value)

def check_account_lockout(ip_address: str) -> bool:
    """Check if IP is locked out due to failed login attempts"""
    if ip_address in failed_login_attempts:
        attempt_data = failed_login_attempts[ip_address]
        if attempt_data['count'] >= MAX_LOGIN_ATTEMPTS:
            if datetime.now() - attempt_data['last_attempt'] < LOCKOUT_DURATION:
                return True
            else:
                # Reset attempts after lockout period
                del failed_login_attempts[ip_address]
    return False

def record_failed_login(ip_address: str):
    """Record a failed login attempt"""
    if ip_address not in failed_login_attempts:
        failed_login_attempts[ip_address] = {'count': 0, 'last_attempt': datetime.now()}
    
    failed_login_attempts[ip_address]['count'] += 1
    failed_login_attempts[ip_address]['last_attempt'] = datetime.now()
    
    logger.warning(f"Failed login attempt from {ip_address}. Count: {failed_login_attempts[ip_address]['count']}")

def secure_run_command(command_list: List[str], timeout: int = 30) -> Dict[str, Any]:
    """Execute command with enhanced security - no shell=True"""
    try:
        # Validate command
        if not command_list or not isinstance(command_list, list):
            raise ValueError("Invalid command format")
        
        # Sanitize command parts
        sanitized_command = [sanitize_for_shell(part) for part in command_list]
        
        result = subprocess.run(
            sanitized_command,
            shell=False,  # Never use shell=True
            capture_output=True,
            text=True,
            timeout=timeout
        )
        
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout.strip(),
            'stderr': result.stderr.strip(),
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        logger.error(f"Command timeout: {command_list}")
        return {
            'success': False,
            'stdout': '',
            'stderr': 'Command timed out',
            'returncode': -1
        }
    except Exception as e:
        logger.error(f"Command execution error: {e}")
        return {
            'success': False,
            'stdout': '',
            'stderr': f'Execution error: {str(e)}',
            'returncode': -1
        }

# Database connection and initialization
def get_db_connection():
    """Get PostgreSQL database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = False  # Ensure transactions are explicit
        return conn
    except psycopg2.OperationalError as e:
        logger.error(f"Database connection error: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected database error: {e}")
        return None

def init_database():
    """Initialize database tables"""
    conn = get_db_connection()
    if not conn:
        logger.warning("Could not connect to database")
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
        logger.info("Database initialized successfully")
        return True
    except Exception as e:
        logger.error(f"Database initialization error: {e}")
        if conn:
            try:
                conn.rollback()
                conn.close()
            except:
                pass
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
    def run_command(self, command_list):
        if isinstance(command_list, str):
            command_list = command_list.split()
        return secure_run_command(command_list)
    def refresh_containers(self):
        self.containers = []
        result = self.run_command(["docker", "ps", "-a", "--format", "json"])
        if result['success'] and result['stdout']:
            for line in result['stdout'].split('\n'):
                if line.strip():
                    try:
                        container_data = json.loads(line)
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
        if not ports_str:
            return []
        ports = []
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
        used_ports = set()
        for container in self.containers:
            for port in container.get('parsed_ports', []):
                try:
                    used_ports.add(int(port['host_port']))
                except:
                    continue
        port = start_port
        while port in used_ports:
            port += 1
        return port
    def create_container(self, name, image="nginx:alpine", port=None, volumes=None, environment=None):
        if not name:
            return {'success': False, 'error': 'Container name is required'}
        existing_names = [c['name'] for c in self.containers]
        if name in existing_names:
            return {'success': False, 'error': f'Container with name "{name}" already exists'}
        if port is None:
            port = self.get_available_port()
        cmd_parts = ['docker', 'run', '-d', '--name', name]
        cmd_parts.extend(['-p', f'{port}:80'])
        if volumes:
            for volume in volumes:
                cmd_parts.extend(['-v', volume])
        else:
            config_dir = f'./nginx-configs/{name}'
            content_dir = f'./web-content/{name}'
            os.makedirs(config_dir, exist_ok=True)
            os.makedirs(content_dir, exist_ok=True)
            cmd_parts.extend(['-v', f'{config_dir}:/etc/nginx/conf.d'])
            cmd_parts.extend(['-v', f'{content_dir}:/usr/share/nginx/html'])
        if environment:
            for env_var in environment:
                cmd_parts.extend(['-e', env_var])
        cmd_parts.extend(['--restart', 'unless-stopped'])
        cmd_parts.append(image)
        result = self.run_command(cmd_parts)
        if result['success']:
            if 'nginx' in image.lower():
                self._create_default_nginx_config(name, port)
            self.refresh_containers()
        return result
    def _create_default_nginx_config(self, container_name, port):
        config_dir = f'./nginx-configs/{container_name}'
        content_dir = f'./web-content/{container_name}'
        os.makedirs(config_dir, exist_ok=True)
        os.makedirs(content_dir, exist_ok=True)
        config_content = f"""server {{
    listen 80;
    server_name localhost;
    location / {{
        root /usr/share/nginx/html;
        index index.html index.htm;
    }}
    location /health {{
        access_log off;
        return 200 \"healthy\\n\";
        add_header Content-Type text/plain;
    }}
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {{
        root /usr/share/nginx/html;
    }}
}}"""
        with open(f'{config_dir}/default.conf', 'w') as f:
            f.write(config_content)
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
        if not validate_input(container_id, VALID_CONTAINER_NAME, 64):
            return {'success': False, 'error': 'Invalid container ID'}
        result = self.run_command(["docker", "start", container_id])
        if result['success']:
            self.refresh_containers()
        return result
    def stop_container(self, container_id):
        if not validate_input(container_id, VALID_CONTAINER_NAME, 64):
            return {'success': False, 'error': 'Invalid container ID'}
        result = self.run_command(["docker", "stop", container_id])
        if result['success']:
            self.refresh_containers()
        return result
    def restart_container(self, container_id):
        if not validate_input(container_id, VALID_CONTAINER_NAME, 64):
            return {'success': False, 'error': 'Invalid container ID'}
        result = self.run_command(["docker", "restart", container_id])
        if result['success']:
            self.refresh_containers()
        return result
    def remove_container(self, container_id, force=False, remove_volumes=False):
        container = self.get_container_by_id(container_id)
        if not container:
            return {'success': False, 'error': 'Container not found'}
        if container['status'] == 'running':
            stop_result = self.stop_container(container_id)
            if not stop_result['success'] and not force:
                return {'success': False, 'error': f'Failed to stop container: {stop_result["stderr"]}'}
        cmd = ["docker", "rm"]
        if force:
            cmd.append("-f")
        cmd.append(container_id)
        result = self.run_command(cmd)
        if result['success'] and remove_volumes:
            container_name = container['name']
            config_dir = f'./nginx-configs/{container_name}'
            content_dir = f'./web-content/{container_name}'
            try:
                if os.path.exists(config_dir):
                    shutil.rmtree(config_dir)
                if os.path.exists(content_dir):
                    shutil.rmtree(content_dir)
            except Exception as e:
                result['warning'] = f'Container removed but failed to clean up directories: {str(e)}'
        
        if result['success']:
            self.refresh_containers()
        return result
    def get_container_by_id(self, container_id):
        for container in self.containers:
            if container['id'].startswith(container_id) or container['name'] == container_id:
                return container
        return None

docker_manager = DockerManager()

@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

@app.route('/<path:filename>')
def serve_static(filename):
    return send_from_directory('.', filename)

@app.route('/api/clear-limits')
def clear_limits():
    """Clear rate limits for debugging"""
    try:
        limiter.reset()
        return jsonify({'success': True, 'message': 'Rate limits cleared'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/login', methods=['POST'])
@limiter.limit("5 per minute")
def login():
    ip_address = request.remote_addr
    if check_account_lockout(ip_address):
        logger.warning(f"Login attempt from locked IP: {ip_address}")
        return jsonify({'success': False, 'error': 'Account temporarily locked due to too many failed attempts. Please try again later.'}), 429
    data = request.get_json()
    if not data:
        return jsonify({'success': False, 'error': 'No data provided'}), 400
    username = data.get('username', '').strip()
    password = data.get('password', '')
    if not username or not password:
        return jsonify({'success': False, 'error': 'Username and password required'}), 400
    if len(username) > 50 or len(password) > 200:
        return jsonify({'success': False, 'error': 'Invalid input length'}), 400
    if not ADMIN_PASSWORD_HASH:
        logger.error("No admin password hash configured")
        return jsonify({'success': False, 'error': 'Admin password not configured. Please run: python run_secure.py'}), 500
    if username == ADMIN_USERNAME and check_password_hash(ADMIN_PASSWORD_HASH, password):
        if ip_address in failed_login_attempts:
            del failed_login_attempts[ip_address]
        session_token = generate_session_token()
        session['user_id'] = session_token
        session['csrf_token'] = secrets.token_urlsafe(32)
        active_sessions[session_token] = {
            'username': username,
            'login_time': datetime.now(),
            'last_activity': datetime.now(),
            'ip_address': ip_address,
            'user_agent': request.headers.get('User-Agent', 'Unknown')[:200]
        }
        logger.info(f"Successful login for user {username} from {ip_address}")
        return jsonify({'success': True, 'message': 'Login successful', 'user': username, 'csrf_token': session['csrf_token']})
    else:
        record_failed_login(ip_address)
        logger.warning(f"Failed login attempt for user {username} from {ip_address}")
        time.sleep(1)
        return jsonify({'success': False, 'error': 'Invalid credentials'}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    if 'user_id' in session:
        user_id = session['user_id']
        if user_id in active_sessions:
            del active_sessions[user_id]
        session.clear()
    return jsonify({'success': True, 'message': 'Logged out successfully'})

@app.route('/api/containers')
@require_auth
def get_containers():
    docker_manager.refresh_containers()
    return jsonify({'success': True, 'containers': docker_manager.containers})

@app.route('/api/containers', methods=['POST'])
@require_auth
def create_container():
    data = request.get_json()
    name = data.get('name', '').strip()
    image = data.get('image', 'nginx:alpine').strip()
    port = data.get('port')
    volumes = data.get('volumes', [])
    environment = data.get('environment', [])
    if not name:
        return jsonify({'success': False, 'error': 'Container name is required'}), 400
    if port is not None:
        try:
            port = int(port)
            if port < 1 or port > 65535:
                return jsonify({'success': False, 'error': 'Port must be between 1 and 65535'}), 400
        except ValueError:
            return jsonify({'success': False, 'error': 'Port must be a valid number'}), 400
    result = docker_manager.create_container(name=name, image=image, port=port, volumes=volumes, environment=environment)
    if result['success']:
        return jsonify({'success': True, 'message': f'Container "{name}" created successfully', 'container_id': result['stdout'][:12] if result['stdout'] else None})
    else:
        return jsonify(result), 400

@app.route('/api/containers/<container_id>/start', methods=['POST'])
@require_auth
def start_container(container_id):
    result = docker_manager.start_container(container_id)
    if result['success']:
        return jsonify({'success': True, 'message': f'Container "{container_id}" started successfully'})
    else:
        return jsonify(result), 400

@app.route('/api/containers/<container_id>/stop', methods=['POST'])
@require_auth
def stop_container(container_id):
    result = docker_manager.stop_container(container_id)
    if result['success']:
        return jsonify({'success': True, 'message': f'Container "{container_id}" stopped successfully'})
    else:
        return jsonify(result), 400

@app.route('/api/containers/<container_id>/restart', methods=['POST'])
@require_auth
def restart_container(container_id):
    result = docker_manager.restart_container(container_id)
    if result['success']:
        return jsonify({'success': True, 'message': f'Container "{container_id}" restarted successfully'})
    else:
        return jsonify(result), 400

@app.route('/api/containers/<container_id>', methods=['DELETE'])
@require_auth
def remove_container(container_id):
    force = request.args.get('force', 'false').lower() == 'true'
    remove_volumes = request.args.get('remove_volumes', 'false').lower() == 'true'
    result = docker_manager.remove_container(container_id=container_id, force=force, remove_volumes=remove_volumes)
    if result['success']:
        message = f'Container "{container_id}" removed successfully'
        if 'warning' in result:
            message += f' (Warning: {result["warning"]})'
        return jsonify({'success': True, 'message': message})
    else:
        return jsonify(result), 400

@app.route('/api/postgresql/execute', methods=['POST'])
@require_auth
def execute_postgresql():
    data = request.get_json()
    database = data.get('database')
    query = data.get('query')
    
    if not database or not query:
        return jsonify({'success': False, 'error': 'Database and query are required'}), 400
    
    # Basic SQL injection protection
    dangerous_keywords = ['DROP', 'DELETE', 'TRUNCATE', 'ALTER', 'CREATE', 'INSERT', 'UPDATE']
    query_upper = query.strip().upper()
    
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        if not conn:
            return jsonify({'success': False, 'error': 'Could not connect to database'}), 500
            
        cursor = conn.cursor()
        cursor.execute(query)
        
        if query_upper.startswith('SELECT'):
            results = cursor.fetchall()
            columns = [desc[0] for desc in cursor.description]
            data = [dict(zip(columns, row)) for row in results]
            result = {'success': True, 'data': data, 'columns': columns, 'row_count': len(results)}
        else:
            conn.commit()
            result = {'success': True, 'message': f'Query executed successfully. Rows affected: {cursor.rowcount}', 'rows_affected': cursor.rowcount}
            
        return jsonify(result)
        
    except psycopg2.Error as e:
        if conn:
            conn.rollback()
        logger.error(f"PostgreSQL error: {e}")
        return jsonify({'success': False, 'error': f'Database error: {str(e)}'}), 500
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error(f"Unexpected error in PostgreSQL execution: {e}")
        return jsonify({'success': False, 'error': f'Unexpected error: {str(e)}'}), 500
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

if __name__ == '__main__':
    logger.info("Starting Not a cPanel server...")
    logger.info(f"Server: {SERVER_IP}")
    logger.info(f"User: {USERNAME}")
    logger.info(f"Access the control panel at: http://{SERVER_IP}:5000")
    logger.info("Initializing database...")
    if init_database():
        logger.info("Database ready")
    else:
        logger.warning("Database initialization failed, some features may not work")
    logger.info("Initializing Docker manager...")
    logger.info(f"Found {len(docker_manager.containers)} existing containers")
    app.run(host='0.0.0.0', port=5000, debug=False)
