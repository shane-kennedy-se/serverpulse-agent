"""
Crash Detector
Monitors system logs for crashes, kernel panics, and critical errors
"""

import re
import time
import threading
from datetime import datetime
from pathlib import Path


class CrashDetector:
    """Detect system crashes and critical errors from log files"""
    
    def __init__(self, log_paths=None, logger=None):
        self.log_paths = log_paths or ['/var/log/syslog', '/var/log/kern.log', '/var/log/messages']
        self.logger = logger
        self.running = False
        self.file_positions = {}
        
        # Crash patterns to look for
        self.crash_patterns = [
            # Kernel panics
            r'kernel:.*panic.*',
            r'kernel:.*Oops.*',
            r'kernel:.*BUG.*',
            r'kernel:.*Call Trace.*',
            
            # Segmentation faults
            r'segfault.*',
            r'general protection fault.*',
            
            # Out of memory
            r'Out of memory.*',
            r'oom-killer.*',
            r'Memory cgroup out of memory.*',
            
            # Hardware errors
            r'Machine check events logged.*',
            r'Hardware Error.*',
            r'EDAC.*error.*',
            
            # Service crashes
            r'.*service.*failed.*',
            r'.*systemd.*failed.*',
            r'.*crashed.*',
            
            # Filesystem errors
            r'.*filesystem.*error.*',
            r'.*I/O error.*',
            r'.*corruption.*',
            
            # Network errors
            r'.*network.*unreachable.*',
            r'.*connection.*refused.*'
        ]
        
        # Compile patterns for better performance
        self.compiled_patterns = [re.compile(pattern, re.IGNORECASE) for pattern in self.crash_patterns]
    
    def start_monitoring(self, stop_event, callback=None):
        """Start monitoring log files for crashes"""
        self.running = True
        
        if self.logger:
            self.logger.info(f"Starting crash detection monitoring on: {', '.join(self.log_paths)}")
        
        # Initialize file positions
        for log_path in self.log_paths:
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
                time.sleep(5)  # Check every 5 seconds for crashes
            except Exception as e:
                if self.logger:
                    self.logger.error(f"Error in crash detection loop: {e}")
                time.sleep(30)
    
    def _check_log_files(self, callback=None):
        """Check log files for new crash entries"""
        for log_path in self.log_paths:
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
                    
                    # Check each new line for crash patterns
                    for line in new_lines:
                        crash_info = self._analyze_line(line.strip(), log_path)
                        if crash_info and callback:
                            callback(crash_info)
                            
            except Exception as e:
                if self.logger:
                    self.logger.error(f"Error reading {log_path}: {e}")
    
    def _analyze_line(self, line, log_path):
        """Analyze a log line for crash patterns"""
        if not line:
            return None
        
        # Check against all patterns
        for pattern in self.compiled_patterns:
            if pattern.search(line):
                return self._extract_crash_info(line, log_path, pattern.pattern)
        
        return None
    
    def _extract_crash_info(self, line, log_path, pattern):
        """Extract detailed crash information from log line"""
        crash_info = {
            'timestamp': self._extract_timestamp(line),
            'log_file': log_path,
            'raw_line': line,
            'pattern_matched': pattern,
            'severity': self._determine_severity(line),
            'cause': self._determine_cause(line),
            'process': self._extract_process_info(line),
            'additional_info': self._extract_additional_info(line)
        }
        
        return crash_info
    
    def _extract_timestamp(self, line):
        """Extract timestamp from log line"""
        # Common log timestamp patterns
        timestamp_patterns = [
            r'(\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2})',  # Dec 25 14:30:45
            r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})',  # 2023-12-25T14:30:45
            r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})'  # 2023-12-25 14:30:45
        ]
        
        for pattern in timestamp_patterns:
            match = re.search(pattern, line)
            if match:
                return match.group(1)
        
        # If no timestamp found, use current time
        return datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    
    def _determine_severity(self, line):
        """Determine severity of the crash/error"""
        line_lower = line.lower()
        
        if any(word in line_lower for word in ['panic', 'oops', 'fatal', 'critical']):
            return 'critical'
        elif any(word in line_lower for word in ['error', 'fail', 'segfault']):
            return 'high'
        elif any(word in line_lower for word in ['warning', 'warn']):
            return 'medium'
        else:
            return 'low'
    
    def _determine_cause(self, line):
        """Determine the likely cause of the crash"""
        line_lower = line.lower()
        
        # Kernel issues
        if 'kernel' in line_lower and ('panic' in line_lower or 'oops' in line_lower):
            return 'kernel_panic'
        elif 'segfault' in line_lower:
            return 'segmentation_fault'
        elif 'out of memory' in line_lower or 'oom' in line_lower:
            return 'out_of_memory'
        elif 'hardware error' in line_lower or 'machine check' in line_lower:
            return 'hardware_error'
        elif 'filesystem' in line_lower and 'error' in line_lower:
            return 'filesystem_error'
        elif 'i/o error' in line_lower:
            return 'io_error'
        elif 'network' in line_lower and ('unreachable' in line_lower or 'refused' in line_lower):
            return 'network_error'
        elif 'service' in line_lower and 'failed' in line_lower:
            return 'service_failure'
        else:
            return 'unknown'
    
    def _extract_process_info(self, line):
        """Extract process information from log line"""
        # Look for process name and PID patterns
        process_patterns = [
            r'(\w+)\[\d+\]',  # process_name[pid]
            r'(\w+):\s*pid\s*(\d+)',  # process: pid 1234
            r'Process\s+(\w+)\s+\((\d+)\)'  # Process name (pid)
        ]
        
        for pattern in process_patterns:
            match = re.search(pattern, line)
            if match:
                if len(match.groups()) >= 2:
                    return {'name': match.group(1), 'pid': match.group(2)}
                else:
                    return {'name': match.group(1), 'pid': None}
        
        return None
    
    def _extract_additional_info(self, line):
        """Extract additional context information"""
        info = {}
        
        # Extract memory addresses
        addr_match = re.search(r'0x[0-9a-fA-F]+', line)
        if addr_match:
            info['memory_address'] = addr_match.group()
        
        # Extract signal information
        signal_match = re.search(r'signal\s+(\d+)', line, re.IGNORECASE)
        if signal_match:
            info['signal'] = signal_match.group(1)
        
        # Extract IP addresses
        ip_match = re.search(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', line)
        if ip_match:
            info['ip_address'] = ip_match.group()
        
        return info
    
    def stop(self):
        """Stop crash monitoring"""
        self.running = False
