"""
Configuration Management
Handles loading and managing agent configuration
"""

import yaml
import os
from pathlib import Path


class Config:
    """Configuration manager for ServerPulse agent"""
    
    def __init__(self, config_path="/etc/serverpulse-agent/config.yml"):
        self.config_path = config_path
        self.config_data = {}
        self.load_config()
    
    def load_config(self):
        """Load configuration from file"""
        try:
            if Path(self.config_path).exists():
                with open(self.config_path, 'r') as f:
                    self.config_data = yaml.safe_load(f) or {}
            else:
                # Create default config if not exists
                self.create_default_config()
                
        except yaml.YAMLError as e:
            raise Exception(f"Error parsing config file {self.config_path}: {e}")
        except Exception as e:
            raise Exception(f"Error loading config file {self.config_path}: {e}")
    
    def create_default_config(self):
        """Create a default configuration file"""
        default_config = {
            'server': {
                'endpoint': 'https://your-serverpulse-domain.com',
                'auth_token': 'your-auth-token-here',
                'agent_id': 'auto-generated-or-custom-id'
            },
            'collection': {
                'interval': 30,  # seconds
                'metrics': [
                    'system_stats',
                    'disk_usage',
                    'network_stats',
                    'process_list'
                ]
            },
            'monitoring': {
                'services': [
                    'ssh',
                    'nginx',
                    'mysql',
                    'docker'
                ],
                'log_paths': [
                    '/var/log/syslog',
                    '/var/log/kern.log'
                ],
                'custom_logs': [
                    {
                        'path': '/var/log/auth.log',
                        'parser': 'auth',
                        'patterns': [
                            'Failed password.*',
                            'Invalid user.*'
                        ]
                    }
                ]
            },
            'alerts': {
                'cpu_threshold': 80,
                'memory_threshold': 85,
                'disk_threshold': 90,
                'load_threshold': 5.0
            },
            'logging': {
                'level': 'INFO',
                'file': '/var/log/serverpulse-agent.log',
                'max_size': '10MB',
                'backup_count': 5
            }
        }
        
        # Create directory if not exists
        config_dir = Path(self.config_path).parent
        config_dir.mkdir(parents=True, exist_ok=True)
        
        # Write default config
        with open(self.config_path, 'w') as f:
            yaml.dump(default_config, f, default_flow_style=False, indent=2)
        
        self.config_data = default_config
        print(f"Created default configuration at {self.config_path}")
        print("Please edit the configuration file with your ServerPulse details")
    
    def get(self, key_path, default=None):
        """Get configuration value using dot notation (e.g., 'server.endpoint')"""
        keys = key_path.split('.')
        value = self.config_data
        
        try:
            for key in keys:
                value = value[key]
            return value
        except (KeyError, TypeError):
            return default
    
    def set(self, key_path, value):
        """Set configuration value using dot notation"""
        keys = key_path.split('.')
        config = self.config_data
        
        # Navigate to the parent of the target key
        for key in keys[:-1]:
            if key not in config:
                config[key] = {}
            config = config[key]
        
        # Set the value
        config[keys[-1]] = value
    
    def save(self):
        """Save configuration to file"""
        try:
            with open(self.config_path, 'w') as f:
                yaml.dump(self.config_data, f, default_flow_style=False, indent=2)
        except Exception as e:
            raise Exception(f"Error saving config file {self.config_path}: {e}")
    
    def validate(self):
        """Validate required configuration settings"""
        required_settings = [
            'server.endpoint',
            'server.auth_token',
            'server.agent_id'
        ]
        
        missing_settings = []
        for setting in required_settings:
            if not self.get(setting):
                missing_settings.append(setting)
        
        if missing_settings:
            raise Exception(f"Missing required configuration settings: {', '.join(missing_settings)}")
        
        # Validate URL format
        endpoint = self.get('server.endpoint')
        if not (endpoint.startswith('http://') or endpoint.startswith('https://')):
            raise Exception("server.endpoint must start with http:// or https://")
        
        # Validate numeric settings
        interval = self.get('collection.interval', 30)
        if not isinstance(interval, int) or interval < 1:
            raise Exception("collection.interval must be a positive integer")
        
        return True
    
    def get_all(self):
        """Get all configuration data"""
        return self.config_data.copy()
    
    def reload(self):
        """Reload configuration from file"""
        self.load_config()
    
    def setup_environment(self):
        """Setup environment variables from config"""
        # Set up proxy settings if configured
        proxy_settings = self.get('network.proxy')
        if proxy_settings:
            if proxy_settings.get('http'):
                os.environ['HTTP_PROXY'] = proxy_settings['http']
            if proxy_settings.get('https'):
                os.environ['HTTPS_PROXY'] = proxy_settings['https']
            if proxy_settings.get('no_proxy'):
                os.environ['NO_PROXY'] = proxy_settings['no_proxy']
