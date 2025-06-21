"""
Log Monitor
Monitors custom log files for specific events and errors
"""

import re
import time
import threading
from datetime import datetime
from pathlib import Path


class LogMonitor:
    """Monitor custom log files for events and errors"""
    
    def __init__(self, log_configs=None, logger=None):
        self.log_configs = log_configs or []
        self.logger = logger
        self.running = False
        self.file_positions = {}
        
        # Default log configurations if none provided
        if not self.log_configs:
            self.log_configs = self._get_default_log_configs()
    
    def _get_default_log_configs(self):
        """Get default log configurations for common services"""
        return [
            {
                'path': '/var/log/auth.log',
                'parser': 'auth',
                'patterns': [
                    r'Failed password.*',
                    r'Invalid user.*',
                    r'authentication failure.*'
                ]
            },
            {
                'path': '/var/log/nginx/error.log',
                'parser': 'nginx',
                'patterns': [
                    r'.*\[error\].*',
                    r'.*\[crit\].*',
                    r'.*\[alert\].*',
                    r'.*\[emerg\].*'
                ]
            },
            {
                'path': '/var/log/apache2/error.log',
                'parser': 'apache',
                'patterns': [
                    r'.*\[error\].*',
                    r'.*\[crit\].*',
                    r'.*\[alert\].*',
                    r'.*\[emerg\].*'
                ]
            },
            {
                'path': '/var/log/mysql/error.log',
                'parser': 'mysql',
                'patterns': [
                    r'.*ERROR.*',
                    r'.*FATAL.*',
                    r'.*Aborted connection.*'
                ]
            }
        ]
    
    def start_monitoring(self, stop_event, callback=None):
        """Start monitoring log files"""
        self.running = True
        
        if self.logger:
            log_paths = [config['path'] for config in self.log_configs]
            self.logger.info(f"Starting log monitoring on: {', '.join(log_paths)}")
        
        # Initialize file positions
        for config in self.log_configs:
            log_path = config['path']
            if Path(log_path).exists():
                try:
                    with open(log_path, 'r') as f:
                        # Start from end of file
                        f.seek(0, 2)
                        self.file_positions[log_path] = f.tell()
                except Exception as e:
                    if self.logger:
                        self.logger.warning(f"Cannot read {log_path}: {e}")
                    self.file_positions[log_path] = 0
        
        while not stop_event.is_set() and self.running:
            try:
                self._check_log_files(callback)
                time.sleep(10)  # Check every 10 seconds
            except Exception as e:
                if self.logger:
                    self.logger.error(f"Error in log monitoring loop: {e}")
                time.sleep(60)
    
    def _check_log_files(self, callback=None):
        """Check log files for new events"""
        for config in self.log_configs:
            log_path = config['path']
            
            if not Path(log_path).exists():
                continue
            
            try:
                with open(log_path, 'r') as f:
                    # Seek to last known position
                    current_pos = self.file_positions.get(log_path, 0)
                    f.seek(current_pos)
                    
                    # Read new lines
                    new_lines = f.readlines()
                    
                    # Update position
                    self.file_positions[log_path] = f.tell()
                    
                    # Check each new line
                    for line in new_lines:
                        event = self._analyze_line(line.strip(), config)
                        if event and callback:
                            callback(event)
                            
            except Exception as e:
                if self.logger:
                    self.logger.error(f"Error reading {log_path}: {e}")
    
    def _analyze_line(self, line, config):
        """Analyze a log line based on configuration"""
        if not line:
            return None
        
        # Check against patterns
        for pattern in config.get('patterns', []):
            if re.search(pattern, line, re.IGNORECASE):
                return self._parse_log_line(line, config, pattern)
        
        return None
    
    def _parse_log_line(self, line, config, matched_pattern):
        """Parse a log line and extract event information"""
        parser_type = config.get('parser', 'generic')
        
        if parser_type == 'auth':
            return self._parse_auth_log(line, config, matched_pattern)
        elif parser_type == 'nginx':
            return self._parse_nginx_log(line, config, matched_pattern)
        elif parser_type == 'apache':
            return self._parse_apache_log(line, config, matched_pattern)
        elif parser_type == 'mysql':
            return self._parse_mysql_log(line, config, matched_pattern)
        else:
            return self._parse_generic_log(line, config, matched_pattern)
    
    def _parse_auth_log(self, line, config, pattern):
        """Parse authentication log entries"""
        event = {
            'type': 'auth_event',
            'log_file': config['path'],
            'timestamp': self._extract_timestamp(line),
            'raw_line': line,
            'pattern_matched': pattern,
            'severity': 'medium'
        }
        
        # Extract specific auth information
        if 'Failed password' in line:
            event['event_type'] = 'failed_login'
            event['severity'] = 'high'
            
            # Extract username and IP
            user_match = re.search(r'user\s+(\w+)', line)
            if user_match:
                event['username'] = user_match.group(1)
            
            ip_match = re.search(r'from\s+([0-9.]+)', line)
            if ip_match:
                event['source_ip'] = ip_match.group(1)
        
        elif 'Invalid user' in line:
            event['event_type'] = 'invalid_user'
            event['severity'] = 'high'
            
            user_match = re.search(r'Invalid user\s+(\w+)', line)
            if user_match:
                event['username'] = user_match.group(1)
        
        return event
    
    def _parse_nginx_log(self, line, config, pattern):
        """Parse nginx error log entries"""
        event = {
            'type': 'nginx_error',
            'log_file': config['path'],
            'timestamp': self._extract_timestamp(line),
            'raw_line': line,
            'pattern_matched': pattern
        }
        
        # Determine severity from log level
        if '[emerg]' in line:
            event['severity'] = 'critical'
        elif '[alert]' in line or '[crit]' in line:
            event['severity'] = 'high'
        elif '[error]' in line:
            event['severity'] = 'medium'
        else:
            event['severity'] = 'low'
        
        # Extract client IP if available
        client_match = re.search(r'client:\s+([0-9.]+)', line)
        if client_match:
            event['client_ip'] = client_match.group(1)
        
        return event
    
    def _parse_apache_log(self, line, config, pattern):
        """Parse Apache error log entries"""
        event = {
            'type': 'apache_error',
            'log_file': config['path'],
            'timestamp': self._extract_timestamp(line),
            'raw_line': line,
            'pattern_matched': pattern
        }
        
        # Determine severity from log level
        if '[emerg]' in line:
            event['severity'] = 'critical'
        elif '[alert]' in line or '[crit]' in line:
            event['severity'] = 'high'
        elif '[error]' in line:
            event['severity'] = 'medium'
        else:
            event['severity'] = 'low'
        
        # Extract client IP if available
        client_match = re.search(r'client\s+([0-9.]+)', line)
        if client_match:
            event['client_ip'] = client_match.group(1)
        
        return event
    
    def _parse_mysql_log(self, line, config, pattern):
        """Parse MySQL error log entries"""
        event = {
            'type': 'mysql_error',
            'log_file': config['path'],
            'timestamp': self._extract_timestamp(line),
            'raw_line': line,
            'pattern_matched': pattern
        }
        
        # Determine severity
        if 'FATAL' in line:
            event['severity'] = 'critical'
        elif 'ERROR' in line:
            event['severity'] = 'high'
        else:
            event['severity'] = 'medium'
        
        return event
    
    def _parse_generic_log(self, line, config, pattern):
        """Parse generic log entries"""
        event = {
            'type': 'log_event',
            'log_file': config['path'],
            'timestamp': self._extract_timestamp(line),
            'raw_line': line,
            'pattern_matched': pattern,
            'severity': 'medium'
        }
        
        # Try to determine severity from common keywords
        line_lower = line.lower()
        if any(word in line_lower for word in ['fatal', 'critical', 'emergency']):
            event['severity'] = 'critical'
        elif any(word in line_lower for word in ['error', 'fail']):
            event['severity'] = 'high'
        elif any(word in line_lower for word in ['warning', 'warn']):
            event['severity'] = 'medium'
        else:
            event['severity'] = 'low'
        
        return event
    
    def _extract_timestamp(self, line):
        """Extract timestamp from log line"""
        # Common log timestamp patterns
        timestamp_patterns = [
            r'(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})',  # Dec 25 14:30:45
            r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})',  # 2023-12-25T14:30:45
            r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})', # 2023-12-25 14:30:45
            r'(\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2})'   # 25/Dec/2023:14:30:45
        ]
        
        for pattern in timestamp_patterns:
            match = re.search(pattern, line)
            if match:
                return match.group(1)
        
        # If no timestamp found, use current time
        return datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    def stop(self):
        """Stop log monitoring"""
        self.running = False
