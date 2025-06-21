#!/usr/bin/env python3
"""
Test Laravel connection for ServerPulse Agent
This script tests if your agent can connect to your Laravel ServerPulse backend
"""

import sys
import requests
import json
from datetime import datetime

def test_laravel_connection():
    """Test connection to Laravel ServerPulse backend"""
    
    print("ServerPulse Agent - Laravel Connection Test")
    print("==========================================")
    
    # Get connection details from user
    laravel_url = input("Enter your Laravel ServerPulse URL (e.g., http://192.168.1.100:80): ").strip()
    auth_token = input("Enter your authentication token: ").strip()
    
    if not laravel_url or not auth_token:
        print("Error: URL and token are required")
        return False
    
    # Ensure URL has proper format
    if not laravel_url.startswith(('http://', 'https://')):
        laravel_url = 'http://' + laravel_url
    
    if not laravel_url.endswith('/api/v1'):
        laravel_url = laravel_url.rstrip('/') + '/api/v1'
    
    print(f"\nTesting connection to: {laravel_url}")
    print("-" * 50)
    
    # Test 1: Agent Registration
    print("1. Testing agent registration...")
    try:
        registration_data = {
            'agent_id': 'test-agent-001',
            'hostname': 'test-ubuntu-vm',
            'system': 'Linux',
            'release': 'Ubuntu 22.04',
            'version': '22.04.3 LTS'
        }
        
        response = requests.post(
            f'{laravel_url}/agents/register',
            json=registration_data,
            headers={
                'Authorization': f'Bearer {auth_token}',
                'Content-Type': 'application/json'
            },
            timeout=10
        )
        
        if response.status_code in [200, 201]:
            print("   ✓ Agent registration successful")
        else:
            print(f"   ✗ Registration failed: {response.status_code} - {response.text}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("   ✗ Connection failed - Laravel server not reachable")
        print(f"     Make sure your Laravel server is running at {laravel_url}")
        return False
    except requests.exceptions.Timeout:
        print("   ✗ Connection timeout")
        return False
    except Exception as e:
        print(f"   ✗ Error: {e}")
        return False
    
    # Test 2: Send test metrics
    print("2. Testing metrics submission...")
    try:
        metrics_data = {
            'agent_id': 'test-agent-001',
            'timestamp': datetime.utcnow().isoformat(),
            'metrics': {
                'cpu': {'usage_percent': 25.5},
                'memory': {'virtual': {'percent': 68.2}},
                'disk': {'usage': {'/': {'percent': 45.1}}},
                'uptime': {'seconds': 86400}
            }
        }
        
        response = requests.post(
            f'{laravel_url}/agents/test-agent-001/metrics',
            json=metrics_data,
            headers={
                'Authorization': f'Bearer {auth_token}',
                'Content-Type': 'application/json'
            },
            timeout=10
        )
        
        if response.status_code in [200, 201]:
            print("   ✓ Metrics submission successful")
        else:
            print(f"   ✗ Metrics submission failed: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"   ✗ Error sending metrics: {e}")
        return False
    
    # Test 3: Send heartbeat
    print("3. Testing heartbeat...")
    try:
        heartbeat_data = {
            'agent_id': 'test-agent-001',
            'timestamp': datetime.utcnow().isoformat(),
            'status': 'online'
        }
        
        response = requests.post(
            f'{laravel_url}/agents/test-agent-001/heartbeat',
            json=heartbeat_data,
            headers={
                'Authorization': f'Bearer {auth_token}',
                'Content-Type': 'application/json'
            },
            timeout=10
        )
        
        if response.status_code in [200, 201]:
            print("   ✓ Heartbeat successful")
        else:
            print(f"   ✗ Heartbeat failed: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"   ✗ Error sending heartbeat: {e}")
        return False
    
    # Test 4: Send test alert
    print("4. Testing alert submission...")
    try:
        alert_data = {
            'agent_id': 'test-agent-001',
            'timestamp': datetime.utcnow().isoformat(),
            'alert': {
                'type': 'test_alert',
                'severity': 'low',
                'message': 'This is a test alert from the agent',
                'details': {'test': True}
            }
        }
        
        response = requests.post(
            f'{laravel_url}/agents/test-agent-001/alerts',
            json=alert_data,
            headers={
                'Authorization': f'Bearer {auth_token}',
                'Content-Type': 'application/json'
            },
            timeout=10
        )
        
        if response.status_code in [200, 201]:
            print("   ✓ Alert submission successful")
        else:
            print(f"   ✗ Alert submission failed: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"   ✗ Error sending alert: {e}")
        return False
    
    print("\n" + "=" * 50)
    print("✓ All tests passed! Your Laravel backend is ready.")
    print("✓ You can now install and configure the agent.")
    print("\nNext steps:")
    print(f"1. Use this URL in your agent config: {laravel_url}")
    print(f"2. Use this token in your agent config: {auth_token}")
    print("3. Run: sudo ./easy_install.sh")
    
    return True

if __name__ == "__main__":
    try:
        success = test_laravel_connection()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\nTest cancelled by user")
        sys.exit(1)
