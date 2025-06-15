#!/usr/bin/env python3
"""
Complete login debug for Not a cPanel
"""

import configparser
from werkzeug.security import generate_password_hash, check_password_hash

def debug_complete_login():
    print("=" * 70)
    print("  🔍 Not a cPanel - Complete Login Debug")
    print("=" * 70)
    
    # Load config
    config = configparser.ConfigParser()
    config.read('config.ini')
    
    # Show ALL relevant variables
    print("📋 Configuration Analysis:")
    print("-" * 40)
    
    # Server config
    server_ip = config.get('server', 'ip', fallback='NOT SET')
    server_username = config.get('server', 'username', fallback='NOT SET')
    password_hash = config.get('admin', 'password_hash', fallback='NOT SET')
    
    print(f"   [server] ip = {server_ip}")
    print(f"   [server] username = {server_username}")
    print(f"   [admin] password_hash = {password_hash[:50] if password_hash != 'NOT SET' else 'NOT SET'}...")
    print()
    
    # Simulate server logic
    print("🔧 Server Logic Simulation:")
    print("-" * 40)
    
    # These are the defaults from server.py
    SERVER_IP = "localhost"
    USERNAME = "user"
    ADMIN_USERNAME = "admin"
    ADMIN_PASSWORD_HASH = None
    
    print(f"   Initial ADMIN_USERNAME = '{ADMIN_USERNAME}'")
    print(f"   Initial USERNAME = '{USERNAME}'")
    print(f"   Initial ADMIN_PASSWORD_HASH = {ADMIN_PASSWORD_HASH}")
    print()
    
    # Simulate load_secure_config()
    print("📂 Simulating load_secure_config():")
    print("-" * 40)
    
    if config.has_section('server'):
        SERVER_IP = config.get('server', 'ip', fallback=SERVER_IP)
        USERNAME = config.get('server', 'username', fallback=USERNAME)
        ADMIN_USERNAME = USERNAME  # This is the key line!
        print(f"   SERVER_IP updated to: '{SERVER_IP}'")
        print(f"   USERNAME updated to: '{USERNAME}'")
        print(f"   ADMIN_USERNAME updated to: '{ADMIN_USERNAME}' (from USERNAME)")
    
    if config.has_section('admin'):
        password_hash = config.get('admin', 'password_hash', fallback=None)
        if password_hash and password_hash.strip():
            ADMIN_PASSWORD_HASH = password_hash.strip()
            print(f"   ADMIN_PASSWORD_HASH loaded: {ADMIN_PASSWORD_HASH[:50]}...")
        else:
            ADMIN_PASSWORD_HASH = None
            print(f"   ADMIN_PASSWORD_HASH is empty or None")
    
    print()
    print("🎯 Final Authentication Variables:")
    print("-" * 40)
    print(f"   ADMIN_USERNAME = '{ADMIN_USERNAME}'")
    print(f"   ADMIN_PASSWORD_HASH = {'SET' if ADMIN_PASSWORD_HASH else 'NOT SET'}")
    print()
    
    # Test login
    print("🔐 Login Test:")
    print("-" * 40)
    
    if not ADMIN_PASSWORD_HASH:
        print("❌ Cannot test login - no password hash configured!")
        return
    
    test_username = input("Enter username to test: ").strip()
    test_password = input("Enter password to test: ").strip()
    
    print(f"\n   Testing: username='{test_username}', password='***'")
    print(f"   Against: ADMIN_USERNAME='{ADMIN_USERNAME}'")
    
    # Username check
    username_match = (test_username == ADMIN_USERNAME)
    print(f"   Username match: {username_match}")
    
    # Password check
    if username_match:
        password_match = check_password_hash(ADMIN_PASSWORD_HASH, test_password)
        print(f"   Password match: {password_match}")
        
        if username_match and password_match:
            print("✅ LOGIN WOULD SUCCEED!")
        else:
            print("❌ LOGIN WOULD FAIL!")
            if not username_match:
                print(f"      Reason: Username '{test_username}' != '{ADMIN_USERNAME}'")
            if not password_match:
                print(f"      Reason: Password doesn't match hash")
    else:
        print("❌ LOGIN WOULD FAIL - Username doesn't match")
        print(f"   Expected: '{ADMIN_USERNAME}'")
        print(f"   Got: '{test_username}'")
    
    print()
    print("💡 Summary:")
    print("-" * 40)
    print(f"   You should login with:")
    print(f"   Username: {ADMIN_USERNAME}")
    print(f"   Password: [the password you set during setup]")

if __name__ == '__main__':
    debug_complete_login()