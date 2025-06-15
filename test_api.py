#!/usr/bin/env python3
"""
Test the actual login API endpoint
"""

import requests
import json

def test_login_api():
    print("=" * 60)
    print("  🌐 Testing Login API Endpoint")
    print("=" * 60)
    
    # Get credentials
    username = input("Enter username: ").strip()
    password = input("Enter password: ").strip()
    
    # Test the API endpoint
    url = "http://localhost:5000/api/login"
    
    payload = {
        "username": username,
        "password": password
    }
    
    headers = {
        "Content-Type": "application/json"
    }
    
    print(f"\n🔗 Testing: {url}")
    print(f"📤 Payload: {json.dumps(payload, indent=2)}")
    print("\n⏳ Sending request...")
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=10)
        
        print(f"\n📊 Response Status: {response.status_code}")
        print(f"📋 Response Headers: {dict(response.headers)}")
        
        try:
            response_json = response.json()
            print(f"📄 Response Body: {json.dumps(response_json, indent=2)}")
            
            if response_json.get('success'):
                print("\n✅ API LOGIN SUCCESSFUL!")
                print("   The API is working correctly.")
                print("   The issue is likely in the frontend JavaScript.")
            else:
                print("\n❌ API LOGIN FAILED!")
                print(f"   Error: {response_json.get('error', 'Unknown error')}")
                
        except json.JSONDecodeError:
            print(f"📄 Response Body (raw): {response.text}")
            
    except requests.exceptions.ConnectionError:
        print("\n❌ CONNECTION ERROR!")
        print("   Cannot connect to http://localhost:5000")
        print("   Make sure the server is running on port 5000")
        
    except requests.exceptions.Timeout:
        print("\n❌ TIMEOUT ERROR!")
        print("   The server took too long to respond")
        
    except Exception as e:
        print(f"\n❌ UNEXPECTED ERROR: {e}")

if __name__ == '__main__':
    test_login_api()