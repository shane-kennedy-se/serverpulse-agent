#!/usr/bin/env python3
"""
ServerPulse Agent Test Script
Tests if the agent can collect metrics and connect to ServerPulse
"""

import os
import sys
import json
import yaml
import requests
import traceback
from datetime import datetime

# Add current directory to path
sys.path.insert(0, '/opt/serverpulse-agent')

def test_config():
    """Test configuration loading"""
    print("🔧 Testing configuration...")
    try:
        config_path = '/opt/serverpulse-agent/config.yml'
        if not os.path.exists(config_path):
            print("❌ Configuration file not found")
            return False
        
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        required_fields = ['api_endpoint', 'server_id']
        for field in required_fields:
            if not config.get(field):
                print(f"❌ Missing required config field: {field}")
                return False
        
        print("✅ Configuration is valid")
        return config
    except Exception as e:
        print(f"❌ Configuration error: {e}")
        return False

def test_metrics_collection():
    """Test metrics collection"""
    print("\n📊 Testing metrics collection...")
    try:
        from collectors.system_metrics import SystemMetricsCollector
        collector = SystemMetricsCollector()
        metrics = collector.collect()
        
        if not metrics:
            print("❌ No metrics collected")
            return False
        
        required_metrics = ['cpu', 'memory', 'disk']
        for metric in required_metrics:
            if metric not in metrics:
                print(f"❌ Missing metric: {metric}")
                return False
        
        print("✅ Metrics collection working")
        print(f"   - CPU usage: {metrics['cpu']['usage_percent']}%")
        print(f"   - Memory usage: {metrics['memory']['virtual']['percent']}%")
        print(f"   - Disk partitions: {len(metrics['disk']['partitions'])}")
        return True
    except Exception as e:
        print(f"❌ Metrics collection error: {e}")
        traceback.print_exc()
        return False

def test_api_connection(config):
    """Test API connection to ServerPulse"""
    print("\n🌐 Testing API connection...")
    try:
        api_endpoint = config['api_endpoint']
        server_id = config['server_id']
        api_key = config.get('api_key', '')
        
        # Test data
        test_data = {
            'timestamp': datetime.now().isoformat(),
            'server_id': server_id,
            'status': 'test',
            'hostname': os.uname().nodename
        }
        
        # Headers
        headers = {'Content-Type': 'application/json'}
        if api_key:
            headers['Authorization'] = f'Bearer {api_key}'
        
        # Test URL
        url = f"{api_endpoint.rstrip('/')}/servers/{server_id}/status"
        
        print(f"   Testing connection to: {url}")
        response = requests.post(url, json=test_data, headers=headers, timeout=10)
        
        if response.status_code in [200, 201]:
            print("✅ API connection successful")
            return True
        else:
            print(f"❌ API connection failed: HTTP {response.status_code}")
            print(f"   Response: {response.text[:200]}")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"❌ Cannot connect to ServerPulse at {api_endpoint}")
        print("   Make sure ServerPulse is running and accessible")
        return False
    except Exception as e:
        print(f"❌ API connection error: {e}")
        return False

def test_service_status():
    """Test systemd service status"""
    print("\n🔧 Testing service status...")
    try:
        import subprocess
        
        # Check if service exists
        result = subprocess.run(['systemctl', 'status', 'serverpulse-agent'], 
                              capture_output=True, text=True)
        
        if 'could not be found' in result.stderr:
            print("❌ Service not installed")
            return False
        
        # Check if service is enabled
        result = subprocess.run(['systemctl', 'is-enabled', 'serverpulse-agent'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Service is enabled for auto-start")
        else:
            print("⚠️ Service is not enabled for auto-start")
        
        # Check if service is running
        result = subprocess.run(['systemctl', 'is-active', 'serverpulse-agent'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✅ Service is currently running")
        else:
            print("⚠️ Service is not running")
        
        return True
    except Exception as e:
        print(f"❌ Service status error: {e}")
        return False

def main():
    """Run all tests"""
    print("🧪 ServerPulse Agent Test Suite")
    print("=" * 40)
    
    # Test configuration
    config = test_config()
    if not config:
        print("\n❌ Configuration test failed. Please check your config.yml file.")
        return
    
    # Test metrics collection
    metrics_ok = test_metrics_collection()
    
    # Test API connection
    api_ok = test_api_connection(config)
    
    # Test service status
    service_ok = test_service_status()
    
    # Summary
    print("\n" + "=" * 40)
    print("📋 Test Summary:")
    print(f"   Configuration: {'✅' if config else '❌'}")
    print(f"   Metrics Collection: {'✅' if metrics_ok else '❌'}")
    print(f"   API Connection: {'✅' if api_ok else '❌'}")
    print(f"   Service Status: {'✅' if service_ok else '❌'}")
    
    if config and metrics_ok and api_ok and service_ok:
        print("\n🎉 All tests passed! Your agent is ready to monitor.")
    else:
        print("\n⚠️ Some tests failed. Please check the issues above.")
        
        if not api_ok:
            print("\n💡 API Connection Tips:")
            print("   - Make sure ServerPulse is running")
            print("   - Check the api_endpoint in config.yml")
            print("   - Verify network connectivity")
            print("   - Check firewall settings")

if __name__ == "__main__":
    main()
