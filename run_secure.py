#!/usr/bin/env python3
"""
Secure startup script for Not a cPanel
This script ensures the application runs with proper security settings
"""

import os
import sys
import secrets
from werkzeug.security import generate_password_hash
import configparser

def check_python_version():
    """Check if Python version is secure"""
    if sys.version_info < (3, 8):
        print("ERROR: Python 3.8+ is required for security reasons")
        sys.exit(1)

def create_secure_config():
    """Create secure configuration if it doesn't exist"""
    config_file = "config.ini"
    
    if os.path.exists(config_file):
        print(f"Configuration file {config_file} already exists")
        return
    
    print("Creating secure configuration...")
    
    # Generate secure password
    admin_password = input("Enter admin password (leave empty for auto-generated): ").strip()
    if not admin_password:
        admin_password = secrets.token_urlsafe(16)
        print(f"Generated admin password: {admin_password}")
        print("IMPORTANT: Save this password securely!")
    
    password_hash = generate_password_hash(admin_password)
    
    # Create configuration
    config = configparser.ConfigParser()
    
    config['server'] = {
        'ip': input("Enter server IP (default: localhost): ") or 'localhost',
        'username': input("Enter admin username (default: admin): ") or 'admin'
    }
    
    config['admin'] = {
        'password_hash': password_hash
    }
    
    config['database'] = {
        'host': input("Enter database host (default: localhost): ") or 'localhost',
        'database': input("Enter database name (default: notacpanel): ") or 'notacpanel',
        'user': input("Enter database user (default: notacpanel): ") or 'notacpanel',
        'password': input("Enter database password (default: notacpanel123): ") or 'notacpanel123',
        'port': input("Enter database port (default: 5432): ") or '5432'
    }
    
    config['security'] = {
        'debug': 'False',
        'force_https': 'False',
        'session_timeout_hours': '4',
        'max_login_attempts': '5',
        'lockout_duration_minutes': '15'
    }
    
    with open(config_file, 'w') as f:
        config.write(f)
    
    # Set secure file permissions (Unix-like systems)
    if hasattr(os, 'chmod'):
        os.chmod(config_file, 0o600)  # Read/write for owner only
    
    print(f"Configuration saved to {config_file}")
    print("IMPORTANT: Keep this file secure and back it up safely!")

def check_environment():
    """Check environment for security issues"""
    print("Checking environment...")
    
    # Check if running as root (not recommended)
    if hasattr(os, 'getuid') and os.getuid() == 0:
        response = input("WARNING: Running as root is not recommended. Continue? (y/N): ")
        if response.lower() != 'y':
            sys.exit(1)
    
    # Check for required directories
    required_dirs = ['nginx-configs', 'web-content', 'logs']
    for dir_name in required_dirs:
        if not os.path.exists(dir_name):
            os.makedirs(dir_name, exist_ok=True)
            print(f"Created directory: {dir_name}")
    
    # Set environment variable for secret key
    if 'SECRET_KEY' not in os.environ:
        os.environ['SECRET_KEY'] = secrets.token_hex(32)
        print("Generated SECRET_KEY environment variable")

def main():
    """Main startup function"""
    print("=" * 50)
    print("  Not a cPanel - Secure Startup")
    print("=" * 50)
    
    check_python_version()
    check_environment()
    create_secure_config()
    
    print("\nStarting secure server...")
    print("Access URL: http://localhost:5000")
    print("Press Ctrl+C to stop the server")
    print("=" * 50)
    
    # Import and run the server
    try:
        import server
        # Set production mode
        server.app.config['DEBUG'] = False
        server.app.run(host='127.0.0.1', port=5000, debug=False)
    except ImportError:
        print("ERROR: server.py not found")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nServer stopped by user")
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()

