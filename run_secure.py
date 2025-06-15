#!/usr/bin/env python3
"""
Secure startup script for Not a cPanel
This script ensures the application runs with proper security settings
"""

import os
import sys
import secrets
import subprocess
import platform
import getpass
from werkzeug.security import generate_password_hash
import configparser

def check_python_version():
    """Check if Python version is secure"""
    if sys.version_info < (3, 8):
        print("ERROR: Python 3.8+ is required for security reasons")
        sys.exit(1)

def load_or_create_config():
    """Load existing config or create new one with prompts"""
    config_file = "config.ini"
    config = configparser.ConfigParser()
    reconfigure = 'n'  # Default value
    
    if os.path.exists(config_file):
        print(f"Loading existing configuration from {config_file}")
        config.read(config_file)
        
        # Check if we need to reconfigure
        reconfigure = input("Reconfigure settings? (y/N): ").strip().lower()
        if reconfigure != 'y':
            return config
        print("Reconfiguring...")
    else:
        print("Creating new secure configuration...")
        reconfigure = 'y'  # Force configuration for new setup
    
    # Get server configuration
    current_ip = config.get('server', 'ip', fallback='0.0.0.0')
    current_username = config.get('server', 'username', fallback='admin')
    
    server_ip = input(f"Enter server IP (current: {current_ip}): ").strip() or current_ip
    username = input(f"Enter admin username (current: {current_username}): ").strip() or current_username
    
    # Get admin password
    password_hash = config.get('admin', 'password_hash', fallback=None)
    
    # Check if password hash is empty or missing
    if not password_hash or password_hash.strip() == '' or reconfigure == 'y':
        print("\n🔐 Setting up admin password...")
        while True:
            admin_password = getpass.getpass("Enter admin password (min 6 characters): ").strip()
            
            if not admin_password:
                # If no password provided and we have an existing hash, keep it
                if password_hash:
                    print("Keeping existing password.")
                    break
                else:
                    # Generate a secure password if none exists
                    admin_password = secrets.token_urlsafe(16)
                    password_hash = generate_password_hash(admin_password)
                    print(f"Generated admin password: {admin_password}")
                    print("IMPORTANT: Save this password securely!")
                    break
            
            if len(admin_password) < 6:
                print("❌ Password must be at least 6 characters long.")
                continue
            
            # Confirm password
            confirm_password = getpass.getpass("Confirm admin password: ").strip()
            if admin_password != confirm_password:
                print("❌ Passwords do not match. Please try again.")
                continue
            
            # Password is valid
            password_hash = generate_password_hash(admin_password)
            print("✅ Password set successfully!")
            break
    else:
        print("ℹ Using existing password configuration.")
    
    # Get database configuration
    current_db_host = config.get('database', 'host', fallback='localhost')
    current_db_name = config.get('database', 'database', fallback='notacpanel')
    current_db_user = config.get('database', 'user', fallback='notacpanel')
    current_db_password = config.get('database', 'password', fallback='notacpanel123')
    current_db_port = config.get('database', 'port', fallback='5432')
    
    db_host = input(f"Enter database host (current: {current_db_host}): ").strip() or current_db_host
    db_name = input(f"Enter database name (current: {current_db_name}): ").strip() or current_db_name
    db_user = input(f"Enter database user (current: {current_db_user}): ").strip() or current_db_user
    db_password = input(f"Enter database password (current: {current_db_password}): ").strip() or current_db_password
    db_port = input(f"Enter database port (current: {current_db_port}): ").strip() or current_db_port
    
    # Create/update configuration
    config['server'] = {
        'ip': server_ip,
        'username': username
    }
    
    config['admin'] = {
        'password_hash': password_hash
    }
    
    config['database'] = {
        'host': db_host,
        'database': db_name,
        'user': db_user,
        'password': db_password,
        'port': db_port
    }
    
    config['security'] = {
        'debug': 'False',
        'force_https': 'False',
        'session_timeout_hours': '4',
        'max_login_attempts': '5',
        'lockout_duration_minutes': '15'
    }
    
    # Save configuration
    with open(config_file, 'w') as f:
        config.write(f)
    
    # Set secure file permissions (Unix-like systems)
    if hasattr(os, 'chmod'):
        os.chmod(config_file, 0o600)  # Read/write for owner only
    
    print(f"Configuration saved to {config_file}")
    return config

def configure_firewall_ports():
    """Configure firewall to allow necessary ports"""
    print("Configuring firewall ports...")
    
    ports_to_open = [5000, 80, 443, 5432, 8000, 8001, 8002, 8003, 8004, 8005]  # Main app + common container ports
    system = platform.system().lower()
    
    try:
        if system == "linux":
            # Check if ufw is available
            result = subprocess.run(['which', 'ufw'], capture_output=True, text=True)
            if result.returncode == 0:
                print("Using UFW firewall...")
                for port in ports_to_open:
                    try:
                        result = subprocess.run(['sudo', 'ufw', 'allow', str(port)], 
                                              capture_output=True, text=True, check=True)
                        print(f"✓ Opened port {port}")
                    except subprocess.CalledProcessError as e:
                        print(f"✗ Failed to open port {port}: {e.stderr.strip()}")
                
                # Enable UFW if not already enabled
                try:
                    result = subprocess.run(['sudo', 'ufw', '--force', 'enable'], 
                                          capture_output=True, text=True, check=True)
                    print("✓ UFW firewall enabled")
                except subprocess.CalledProcessError:
                    print("ℹ UFW may already be enabled")
            else:
                # Try iptables as fallback
                print("UFW not found, trying iptables...")
                for port in ports_to_open:
                    try:
                        subprocess.run(['sudo', 'iptables', '-A', 'INPUT', '-p', 'tcp', 
                                      '--dport', str(port), '-j', 'ACCEPT'], 
                                     capture_output=True, text=True, check=True)
                        print(f"✓ Opened port {port} with iptables")
                    except subprocess.CalledProcessError:
                        print(f"✗ Failed to open port {port} with iptables")
        
        elif system == "windows":
            print("Using Windows Firewall...")
            for port in ports_to_open:
                try:
                    # Check if rule already exists
                    check_result = subprocess.run(['netsh', 'advfirewall', 'firewall', 'show', 'rule',
                                                 f'name=Not-a-cPanel-Port-{port}'], 
                                                capture_output=True, text=True)
                    
                    if "No rules match" in check_result.stdout:
                        # Add inbound rule
                        subprocess.run(['netsh', 'advfirewall', 'firewall', 'add', 'rule',
                                      f'name=Not-a-cPanel-Port-{port}', 'dir=in', 'action=allow',
                                      'protocol=TCP', f'localport={port}'], 
                                     capture_output=True, text=True, check=True)
                        print(f"✓ Opened inbound port {port}")
                    else:
                        print(f"ℹ Port {port} rule already exists")
                except subprocess.CalledProcessError as e:
                    print(f"✗ Failed to configure port {port}: {e.stderr.strip()}")
        
        else:
            print(f"Firewall configuration not supported for {system}")
            print("Please manually configure your firewall to allow ports: " + ", ".join(map(str, ports_to_open)))
    
    except Exception as e:
        print(f"Firewall configuration error: {e}")
        print("Please manually configure your firewall to allow ports: " + ", ".join(map(str, ports_to_open)))

def check_environment():
    """Check environment for security issues"""
    print("Checking environment...")
    
    # Check if running as root (not recommended on Linux)
    if hasattr(os, 'getuid') and os.getuid() == 0:
        response = input("WARNING: Running as root is not recommended. Continue? (y/N): ")
        if response.lower() != 'y':
            sys.exit(1)
    
    # Check for required directories
    required_dirs = ['nginx-configs', 'web-content', 'logs']
    for dir_name in required_dirs:
        if not os.path.exists(dir_name):
            os.makedirs(dir_name, exist_ok=True)
            print(f"✓ Created directory: {dir_name}")
        else:
            print(f"ℹ Directory exists: {dir_name}")
    
    # Set environment variable for secret key
    if 'SECRET_KEY' not in os.environ:
        os.environ['SECRET_KEY'] = secrets.token_hex(32)
        print("✓ Generated SECRET_KEY environment variable")
    else:
        print("ℹ SECRET_KEY already set")

def check_dependencies():
    """Check if required dependencies are available"""
    print("Checking dependencies...")
    
    try:
        import flask
        print("✓ Flask is available")
    except ImportError:
        print("✗ Flask not found. Please install: pip install flask")
        return False
    
    try:
        import psycopg2
        print("✓ psycopg2 is available")
    except ImportError:
        print("✗ psycopg2 not found. Please install: pip install psycopg2-binary")
        return False
    
    try:
        import flask_limiter
        print("✓ Flask-Limiter is available")
    except ImportError:
        print("✗ Flask-Limiter not found. Please install: pip install Flask-Limiter")
        return False
    
    # Check if Docker is available
    try:
        result = subprocess.run(['docker', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"✓ Docker is available: {result.stdout.strip()}")
        else:
            print("⚠ Docker may not be properly installed")
    except FileNotFoundError:
        print("⚠ Docker not found in PATH")
    
    return True

def main():
    """Main startup function"""
    print("=" * 60)
    print("  🐳 Not a cPanel - Secure Startup")
    print("=" * 60)
    
    # Check Python version
    check_python_version()
    print("✓ Python version check passed")
    
    # Check dependencies
    if not check_dependencies():
        print("\n❌ Dependency check failed. Please install missing packages.")
        sys.exit(1)
    
    # Check environment
    check_environment()
    
    # Load or create configuration
    config = load_or_create_config()
    
    # Configure firewall ports
    configure_firewall = input("\nConfigure firewall ports automatically? (Y/n): ").strip().lower()
    if configure_firewall != 'n':
        configure_firewall_ports()
    
    # Get server configuration
    server_ip = config.get('server', 'ip', fallback='0.0.0.0')
    bind_host = '0.0.0.0' if server_ip != 'localhost' else '127.0.0.1'
    
    print("\n" + "=" * 60)
    print("🚀 Starting secure server...")
    print(f"📍 Server IP: {server_ip}")
    print(f"🔗 Access URL: http://{server_ip}:5000")
    print(f"👤 Username: {config.get('server', 'username', fallback='admin')}")
    
    if bind_host == '0.0.0.0':
        print("🌐 Server is accessible from external networks")
    else:
        print("🏠 Server is only accessible locally")
    
    print("🖥️  Starting monitoring display...")
    print("⏹️  Press Ctrl+C to stop both server and monitor")
    print("=" * 60)
    
    # Import and start the server in a separate thread
    try:
        import server
        import threading
        import time
        
        # Set production mode
        server.app.config['DEBUG'] = False
        
        # Start server in background thread
        def run_server():
            server.app.run(host=bind_host, port=5000, debug=False, threaded=True, use_reloader=False)
        
        server_thread = threading.Thread(target=run_server, daemon=True)
        server_thread.start()
        
        # Give server a moment to start
        time.sleep(2)
        
        # Start the watcher display
        if os.path.exists('./watcher.sh'):
            print("🎯 Launching monitoring display...")
            time.sleep(1)
            os.system('bash ./watcher.sh')
        else:
            print("⚠️  watcher.sh not found, server running without monitor")
            print(f"🔗 Access the control panel at: http://{server_ip}:5000")
            # Keep main thread alive
            try:
                while True:
                    time.sleep(1)
            except KeyboardInterrupt:
                print("\n⏹️  Server stopped by user")
                
    except ImportError:
        print("❌ ERROR: server.py not found")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n⏹️  Server and monitor stopped by user")
    except Exception as e:
        print(f"❌ ERROR: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()