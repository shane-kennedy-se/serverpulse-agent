#!/usr/bin/env python3
"""
ServerPulse Agent CLI
Command-line interface for managing the agent
"""

import sys
import argparse
import json
from pathlib import Path
from datetime import datetime

# Add the agent directory to Python path
agent_dir = Path(__file__).parent
sys.path.insert(0, str(agent_dir))

from utils.config import Config
from utils.logger import setup_logger
from collectors.system_metrics import SystemMetricsCollector
from collectors.service_monitor import ServiceMonitor
from communication.api_client import APIClient


def cmd_test_connection(args):
    """Test connection to ServerPulse server"""
    try:
        config = Config(args.config)
        logger = setup_logger('INFO')
        
        client = APIClient(
            endpoint=config.get('server.endpoint'),
            auth_token=config.get('server.auth_token'),
            agent_id=config.get('server.agent_id'),
            logger=logger
        )
        
        print("Testing connection to ServerPulse...")
        if client.test_connection():
            print("✓ Connection successful!")
            return 0
        else:
            print("✗ Connection failed!")
            return 1
            
    except Exception as e:
        print(f"Error: {e}")
        return 1


def cmd_collect_metrics(args):
    """Collect and display current metrics"""
    try:
        logger = setup_logger('WARNING')  # Reduce noise
        collector = SystemMetricsCollector(logger=logger)
        
        print("Collecting system metrics...")
        metrics = collector.collect_all()
        
        if args.json:
            print(json.dumps(metrics, indent=2, default=str))
        else:
            print_metrics_summary(metrics)
        
        return 0
        
    except Exception as e:
        print(f"Error: {e}")
        return 1


def cmd_check_services(args):
    """Check service status"""
    try:
        config = Config(args.config)
        logger = setup_logger('WARNING')
        
        services = config.get('monitoring.services', ['ssh', 'cron'])
        monitor = ServiceMonitor(services, logger=logger)
        
        print("Checking service status...")
        status = monitor.get_service_status()
        
        if args.json:
            print(json.dumps(status, indent=2))
        else:
            print_service_status(status)
        
        return 0
        
    except Exception as e:
        print(f"Error: {e}")
        return 1


def cmd_send_test_alert(args):
    """Send a test alert to ServerPulse"""
    try:
        config = Config(args.config)
        logger = setup_logger('INFO')
        
        client = APIClient(
            endpoint=config.get('server.endpoint'),
            auth_token=config.get('server.auth_token'),
            agent_id=config.get('server.agent_id'),
            logger=logger
        )
        
        test_alert = {
            'type': 'test_alert',
            'severity': 'low',
            'message': 'This is a test alert from the ServerPulse agent',
            'details': {
                'test': True,
                'agent_id': config.get('server.agent_id'),
                'timestamp': datetime.utcnow().isoformat()
            },
            'timestamp': datetime.utcnow().isoformat()
        }
        
        print("Sending test alert...")
        if client.send_alert(test_alert):
            print("✓ Test alert sent successfully!")
            return 0
        else:
            print("✗ Failed to send test alert!")
            return 1
            
    except Exception as e:
        print(f"Error: {e}")
        return 1


def cmd_validate_config(args):
    """Validate configuration file"""
    try:
        config = Config(args.config)
        config.validate()
        print("✓ Configuration is valid!")
        return 0
        
    except Exception as e:
        print(f"✗ Configuration error: {e}")
        return 1


def print_metrics_summary(metrics):
    """Print a human-readable summary of metrics"""
    print("\nSystem Metrics Summary")
    print("=" * 40)
    
    # System info
    info = metrics.get('system_info', {})
    print(f"Hostname: {info.get('hostname', 'Unknown')}")
    print(f"System: {info.get('system', 'Unknown')} {info.get('release', '')}")
    print(f"CPU Cores: {info.get('cpu_count', 'Unknown')}")
    
    # CPU
    cpu = metrics.get('cpu', {})
    print(f"CPU Usage: {cpu.get('usage_percent', 0):.1f}%")
    
    # Memory
    memory = metrics.get('memory', {}).get('virtual', {})
    print(f"Memory Usage: {memory.get('percent', 0):.1f}% ({memory.get('used', 0) // (1024**3):.1f}GB / {memory.get('total', 0) // (1024**3):.1f}GB)")
    
    # Disk
    disk_usage = metrics.get('disk', {}).get('usage', {})
    print("\nDisk Usage:")
    for mount, info in disk_usage.items():
        used_gb = info.get('used', 0) / (1024**3)
        total_gb = info.get('total', 0) / (1024**3)
        percent = info.get('percent', 0)
        print(f"  {mount}: {used_gb:.1f}GB / {total_gb:.1f}GB ({percent:.1f}%)")
    
    # Uptime
    uptime = metrics.get('uptime', {})
    print(f"\nUptime: {uptime.get('uptime_string', 'Unknown')}")
    
    # Load average
    load = metrics.get('load_average', {})
    if load:
        print(f"Load Average: {load.get('1min', 0):.2f}, {load.get('5min', 0):.2f}, {load.get('15min', 0):.2f}")


def print_service_status(status):
    """Print service status in a readable format"""
    print("\nService Status")
    print("=" * 40)
    
    for service, info in status.items():
        status_str = info.get('status', 'unknown')
        active_state = info.get('active_state', 'unknown')
        
        # Color coding
        if status_str == 'active':
            status_icon = "✓"
        elif status_str == 'failed':
            status_icon = "✗"
        else:
            status_icon = "?"
        
        print(f"{status_icon} {service}: {status_str} ({active_state})")


def main():
    """Main CLI function"""
    parser = argparse.ArgumentParser(
        description="ServerPulse Agent CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        '--config', '-c',
        default='/etc/serverpulse-agent/config.yml',
        help='Configuration file path (default: /etc/serverpulse-agent/config.yml)'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Test connection command
    test_parser = subparsers.add_parser('test-connection', help='Test connection to ServerPulse server')
    test_parser.set_defaults(func=cmd_test_connection)
    
    # Collect metrics command
    metrics_parser = subparsers.add_parser('collect-metrics', help='Collect and display current metrics')
    metrics_parser.add_argument('--json', action='store_true', help='Output in JSON format')
    metrics_parser.set_defaults(func=cmd_collect_metrics)
    
    # Check services command
    services_parser = subparsers.add_parser('check-services', help='Check service status')
    services_parser.add_argument('--json', action='store_true', help='Output in JSON format')
    services_parser.set_defaults(func=cmd_check_services)
    
    # Send test alert command
    alert_parser = subparsers.add_parser('send-test-alert', help='Send a test alert to ServerPulse')
    alert_parser.set_defaults(func=cmd_send_test_alert)
    
    # Validate config command
    config_parser = subparsers.add_parser('validate-config', help='Validate configuration file')
    config_parser.set_defaults(func=cmd_validate_config)
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return 1
    
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
