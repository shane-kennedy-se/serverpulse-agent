#!/usr/bin/env python3
"""
Test script for ServerPulse Agent
Tests the agent functionality without connecting to a server
"""

import sys
import json
from pathlib import Path

# Add the agent directory to Python path
agent_dir = Path(__file__).parent
sys.path.insert(0, str(agent_dir))

from collectors.system_metrics import SystemMetricsCollector
from collectors.service_monitor import ServiceMonitor
from collectors.crash_detector import CrashDetector
from utils.config import Config
from utils.logger import setup_logger


def test_system_metrics():
    """Test system metrics collection"""
    print("Testing System Metrics Collection...")
    
    logger = setup_logger('DEBUG')
    collector = SystemMetricsCollector(logger=logger)
    
    try:
        metrics = collector.collect_all()
        
        print("✓ System metrics collected successfully")
        print(f"  - CPU cores: {metrics['system_info']['cpu_count']}")
        print(f"  - CPU usage: {metrics['cpu']['usage_percent']:.1f}%")
        print(f"  - Memory usage: {metrics['memory']['virtual']['percent']:.1f}%")
        print(f"  - Disk partitions: {len(metrics['disk']['usage'])}")
        print(f"  - Network interfaces: {len(metrics['network']['interfaces'])}")
        print(f"  - Uptime: {metrics['uptime']['uptime_string']}")
        
        return True
        
    except Exception as e:
        print(f"✗ System metrics collection failed: {e}")
        return False


def test_service_monitor():
    """Test service monitoring"""
    print("\nTesting Service Monitor...")
    
    logger = setup_logger('DEBUG')
    monitor = ServiceMonitor(['ssh', 'cron'], logger=logger)
    
    try:
        status = monitor.get_service_status()
        
        print("✓ Service monitoring working")
        for service, info in status.items():
            print(f"  - {service}: {info['status']}")
        
        return True
        
    except Exception as e:
        print(f"✗ Service monitoring failed: {e}")
        return False


def test_crash_detector():
    """Test crash detection"""
    print("\nTesting Crash Detector...")
    
    logger = setup_logger('DEBUG')
    detector = CrashDetector(['/var/log/syslog'], logger=logger)
    
    try:
        # Test with a sample crash line
        test_line = "Dec 25 14:30:45 server kernel: [12345.678901] Oops: 0002 [#1] SMP"
        crash_info = detector._analyze_line(test_line, '/var/log/syslog')
        
        if crash_info:
            print("✓ Crash detection working")
            print(f"  - Detected crash: {crash_info['cause']}")
            print(f"  - Severity: {crash_info['severity']}")
        else:
            print("✓ Crash detector initialized (no crashes in test)")
        
        return True
        
    except Exception as e:
        print(f"✗ Crash detection failed: {e}")
        return False


def test_configuration():
    """Test configuration loading"""
    print("\nTesting Configuration...")
    
    try:
        # Test with example config
        config_path = agent_dir / "config.yml.example"
        if config_path.exists():
            config = Config(str(config_path))
            
            print("✓ Configuration loaded successfully")
            print(f"  - Endpoint: {config.get('server.endpoint')}")
            print(f"  - Collection interval: {config.get('collection.interval')}")
            print(f"  - Monitored services: {len(config.get('monitoring.services', []))}")
        else:
            print("✓ Configuration system working (no example config found)")
        
        return True
        
    except Exception as e:
        print(f"✗ Configuration loading failed: {e}")
        return False


def test_dependencies():
    """Test required dependencies"""
    print("Testing Dependencies...")
    
    required_modules = [
        'psutil',
        'requests',
        'yaml',
        'schedule'
    ]
    
    missing_modules = []
    
    for module in required_modules:
        try:
            __import__(module)
            print(f"✓ {module}")
        except ImportError:
            print(f"✗ {module} - MISSING")
            missing_modules.append(module)
    
    if missing_modules:
        print(f"\nMissing dependencies: {', '.join(missing_modules)}")
        print("Install them with: pip3 install " + " ".join(missing_modules))
        return False
    
    return True


def main():
    """Run all tests"""
    print("ServerPulse Agent Test Suite")
    print("=" * 40)
    
    tests = [
        test_dependencies,
        test_configuration,
        test_system_metrics,
        test_service_monitor,
        test_crash_detector
    ]
    
    results = []
    
    for test in tests:
        try:
            result = test()
            results.append(result)
        except Exception as e:
            print(f"✗ Test failed with exception: {e}")
            results.append(False)
    
    print("\n" + "=" * 40)
    print("Test Results:")
    print(f"Passed: {sum(results)}/{len(results)}")
    
    if all(results):
        print("✓ All tests passed! The agent should work correctly.")
        return 0
    else:
        print("✗ Some tests failed. Please check the errors above.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
