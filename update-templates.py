#!/usr/bin/env python3

"""
Template updater for Not a cPanel
Updates HTML and JS files with configuration values
"""

import os
import sys

def update_templates():
    """Update template files with configuration values"""
    
    # Load configuration
    config = {
        'SERVER_IP': 'localhost',
        'USERNAME': 'user'
    }
    
    # Try to load from config.py
    if os.path.exists('config.py'):
        try:
            with open('config.py', 'r') as f:
                exec(f.read(), config)
        except Exception as e:
            print(f"Warning: Could not load config.py: {e}")
    
    server_ip = config.get('SERVER_IP', 'localhost')
    username = config.get('USERNAME', 'user')
    
    print(f"Updating templates with:")
    print(f"  Server IP: {server_ip}")
    print(f"  Username: {username}")
    
    # Update index.html
    if os.path.exists('index.html'):
        with open('index.html', 'r') as f:
            content = f.read()
        
        # Replace placeholders
        content = content.replace('neofloppy@4.221.197.153', f'{username}@{server_ip}')
        content = content.replace('User: neofloppy', f'User: {username}')
        content = content.replace('Server: 4.221.197.153', f'Server: {server_ip}')
        
        with open('index.html', 'w') as f:
            f.write(content)
        
        print("✓ Updated index.html")
    
    # Update script.js
    if os.path.exists('script.js'):
        with open('script.js', 'r') as f:
            content = f.read()
        
        # Replace placeholders
        content = content.replace('neofloppy@4.221.197.153', f'{username}@{server_ip}')
        content = content.replace('/home/neofloppy', f'/home/{username}')
        content = content.replace("'neofloppy'", f"'{username}'")
        
        with open('script.js', 'w') as f:
            f.write(content)
        
        print("✓ Updated script.js")
    
    # Update README.md
    if os.path.exists('README.md'):
        with open('README.md', 'r') as f:
            content = f.read()
        
        # Replace placeholders in documentation
        content = content.replace('SERVER_IP = "4.221.197.153"', f'SERVER_IP = "{server_ip}"')
        content = content.replace('USERNAME = "neofloppy"', f'USERNAME = "{username}"')
        
        with open('README.md', 'w') as f:
            f.write(content)
        
        print("✓ Updated README.md")
    
    print("Template update complete!")

if __name__ == "__main__":
    update_templates()