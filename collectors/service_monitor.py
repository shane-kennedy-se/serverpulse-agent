"""
Service Monitor
Monitors systemd services and their status changes
"""

import subprocess
import time
import threading
from collections import defaultdict


class ServiceMonitor:
    """Monitor systemd services for status changes"""
    
    def __init__(self, services_to_monitor=None, logger=None):
        self.services_to_monitor = services_to_monitor or []
        self.logger = logger
        self.service_status = {}
        self.running = False
        
        # Auto-discover critical services if none specified
        if not self.services_to_monitor:
            self.services_to_monitor = self._discover_critical_services()
    
    def _discover_critical_services(self):
        """Discover critical system services to monitor"""
        critical_services = [
            'ssh', 'sshd', 'networking', 'network-manager',
            'systemd-resolved', 'cron', 'rsyslog', 'ufw',
            'nginx', 'apache2', 'mysql', 'postgresql',
            'docker', 'fail2ban'
        ]
        
        active_services = []
        for service in critical_services:
            if self._is_service_available(service):
                active_services.append(service)
        
        return active_services
    
    def _is_service_available(self, service_name):
        """Check if a service is available on the system"""
        try:
            result = subprocess.run(
                ['systemctl', 'list-unit-files', f'{service_name}.service'],
                capture_output=True,
                text=True,
                timeout=5
            )
            return service_name in result.stdout
        except:
            return False
    
    def get_service_status(self, service_name=None):
        """Get current status of services"""
        if service_name:
            return self._get_single_service_status(service_name)
        
        status_dict = {}
        for service in self.services_to_monitor:
            status_dict[service] = self._get_single_service_status(service)
        
        return status_dict
    
    def _get_single_service_status(self, service_name):
        """Get status of a single service"""
        try:
            # Get service status
            result = subprocess.run(
                ['systemctl', 'is-active', f'{service_name}.service'],
                capture_output=True,
                text=True,
                timeout=5
            )
            status = result.stdout.strip()
            
            # Get additional info
            show_result = subprocess.run(
                ['systemctl', 'show', f'{service_name}.service', 
                 '--property=MainPID,LoadState,ActiveState,SubState,ExecMainStartTimestamp'],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            properties = {}
            for line in show_result.stdout.strip().split('\n'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    properties[key] = value
            
            return {
                'status': status,
                'load_state': properties.get('LoadState', 'unknown'),
                'active_state': properties.get('ActiveState', 'unknown'),
                'sub_state': properties.get('SubState', 'unknown'),
                'main_pid': properties.get('MainPID', '0'),
                'start_timestamp': properties.get('ExecMainStartTimestamp', ''),
                'last_checked': time.time()
            }
            
        except subprocess.TimeoutExpired:
            if self.logger:
                self.logger.warning(f"Timeout checking service {service_name}")
            return {'status': 'timeout', 'last_checked': time.time()}
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error checking service {service_name}: {e}")
            return {'status': 'error', 'error': str(e), 'last_checked': time.time()}
    
    def start_monitoring(self, stop_event, callback=None):
        """Start continuous monitoring of services"""
        self.running = True
        
        if self.logger:
            self.logger.info(f"Starting service monitoring for: {', '.join(self.services_to_monitor)}")
        
        # Initialize service status
        for service in self.services_to_monitor:
            self.service_status[service] = self._get_single_service_status(service)
        
        while not stop_event.is_set() and self.running:
            try:
                self._check_service_changes(callback)
                time.sleep(30)  # Check every 30 seconds
            except Exception as e:
                if self.logger:
                    self.logger.error(f"Error in service monitoring loop: {e}")
                time.sleep(60)  # Wait longer on error
    
    def _check_service_changes(self, callback=None):
        """Check for service status changes"""
        for service in self.services_to_monitor:
            try:
                current_status = self._get_single_service_status(service)
                previous_status = self.service_status.get(service, {})
                
                # Check if status changed
                if (previous_status.get('status') != current_status.get('status') or
                    previous_status.get('active_state') != current_status.get('active_state')):
                    
                    if self.logger:
                        self.logger.info(
                            f"Service {service} status changed: "
                            f"{previous_status.get('status', 'unknown')} -> {current_status.get('status')}"
                        )
                    
                    # Call callback if provided
                    if callback:
                        callback(
                            service,
                            previous_status.get('status', 'unknown'),
                            current_status.get('status')
                        )
                
                # Update stored status
                self.service_status[service] = current_status
                
            except Exception as e:
                if self.logger:
                    self.logger.error(f"Error checking service {service}: {e}")
    
    def get_failed_services(self):
        """Get list of failed services"""
        failed_services = []
        for service, status in self.service_status.items():
            if status.get('status') == 'failed' or status.get('active_state') == 'failed':
                failed_services.append({
                    'name': service,
                    'status': status
                })
        return failed_services
    
    def restart_service(self, service_name):
        """Attempt to restart a failed service"""
        try:
            if self.logger:
                self.logger.info(f"Attempting to restart service: {service_name}")
            
            result = subprocess.run(
                ['sudo', 'systemctl', 'restart', f'{service_name}.service'],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                if self.logger:
                    self.logger.info(f"Successfully restarted service: {service_name}")
                return True
            else:
                if self.logger:
                    self.logger.error(f"Failed to restart service {service_name}: {result.stderr}")
                return False
                
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error restarting service {service_name}: {e}")
            return False
    
    def stop(self):
        """Stop monitoring"""
        self.running = False
