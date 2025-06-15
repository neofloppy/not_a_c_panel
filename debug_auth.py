#!/usr/bin/env python3
"""
Debug authentication for Not a cPanel
"""

import configparser
from werkzeug.security import generate_password_hash, check_password_hash

def debug_auth():
    print("=" * 60)
    print("  🔍 Not a cPanel - Authentication Debug")
    print("=" * 60)
    
    # Load config
    config = configparser.ConfigParser()
    config.read('config.ini')
    
    # Show current config
    print("📋 Current Configuration:")
    print(f"   Server IP: {config.get('server', 'ip', fallback='NOT SET')}")
    print(f"   Username: {config.get('server', 'username', fallback='NOT SET')}")
    print(f"   Password Hash: {config.get('admin', 'password_hash', fallback='NOT SET')}")
    print()
    
    # Check if password hash exists
    password_hash = config.get('admin', 'password_hash', fallback=None)
    if not password_hash or password_hash.strip() == '':
        print("❌ PROBLEM: No password hash found in config!")
        print("   This means the password was never set up properly.")
        print()
        
        # Set up password now
        password = input("Enter a password to set up now: ").strip()
        if password:
            new_hash = generate_password_hash(password)
            config.set('admin', 'password_hash', new_hash)
            
            with open('config.ini', 'w') as f:
                config.write(f)
            
            print(f"✅ Password hash created and saved!")
            print(f"   Hash: {new_hash[:50]}...")
            print(f"   Username: {config.get('server', 'username', fallback='admin')}")
            print(f"   Password: {password}")
        return
    
    print("✅ Password hash found in config")
    print(f"   Hash: {password_hash[:50]}...")
    print()
    
    # Test password verification
    test_password = input("Enter the password you're trying to use: ").strip()
    if test_password:
        is_valid = check_password_hash(password_hash, test_password)
        print(f"🔐 Password verification result: {'✅ VALID' if is_valid else '❌ INVALID'}")
        
        if not is_valid:
            print("   The password you entered doesn't match the stored hash.")
            print("   Either the password is wrong, or the hash was corrupted.")
            
            # Offer to reset
            reset = input("   Do you want to reset the password? (y/N): ").strip().lower()
            if reset == 'y':
                new_password = input("   Enter new password: ").strip()
                if new_password:
                    new_hash = generate_password_hash(new_password)
                    config.set('admin', 'password_hash', new_hash)
                    
                    with open('config.ini', 'w') as f:
                        config.write(f)
                    
                    print(f"✅ Password reset successfully!")
                    print(f"   Username: {config.get('server', 'username', fallback='admin')}")
                    print(f"   Password: {new_password}")

if __name__ == '__main__':
    debug_auth()