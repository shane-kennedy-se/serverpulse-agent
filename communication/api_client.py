"""
API Client
Handles communication with ServerPulse server
"""

import json
import time
import requests
import platform
from datetime import datetime


class APIClient:
    """Client for communicating with ServerPulse API"""
    
    def __init__(self, endpoint, auth_token, agent_id, logger=None):
        self.endpoint = endpoint.rstrip('/')
        self.auth_token = auth_token
        self.agent_id = agent_id
        self.logger = logger
        self.session = requests.Session()
        
        # Set default headers
        self.session.headers.update({
            'Authorization': f'Bearer {auth_token}',
            'Content-Type': 'application/json',
            'User-Agent': f'ServerPulse-Agent/1.0 ({platform.system()})'
        })
        
        # Timeout and retry settings
        self.timeout = 30
        self.max_retries = 3
        
    def register_agent(self):
        """Register this agent with the ServerPulse server"""
        try:
            uname = platform.uname()
            registration_data = {
                'agent_id': self.agent_id,
                'hostname': uname.node,
                'system': uname.system,
                'release': uname.release,
                'version': uname.version,
                'machine': uname.machine,
                'processor': uname.processor,
                'agent_version': '1.0.0',
                'registration_time': datetime.utcnow().isoformat()
            }
            
            response = self._make_request(
                'POST',
                f'{self.endpoint}/api/v1/agents/register',
                data=registration_data
            )
            
            if response and response.status_code in [200, 201]:
                if self.logger:
                    self.logger.info("Agent registered successfully with ServerPulse")
                return True
            else:
                if self.logger:
                    self.logger.error(f"Failed to register agent: {response.status_code if response else 'No response'}")
                return False
                
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error registering agent: {e}")
            return False
    
    def send_metrics(self, metrics_data):
        """Send metrics data to ServerPulse"""
        try:
            payload = {
                'agent_id': self.agent_id,
                'timestamp': datetime.utcnow().isoformat(),
                'metrics': metrics_data
            }
            
            response = self._make_request(
                'POST',
                f'{self.endpoint}/api/v1/agents/{self.agent_id}/metrics',
                data=payload
            )
            
            if response and response.status_code in [200, 201]:
                if self.logger:
                    self.logger.debug("Metrics sent successfully")
                return True
            else:
                if self.logger:
                    self.logger.warning(f"Failed to send metrics: {response.status_code if response else 'No response'}")
                return False
                
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error sending metrics: {e}")
            return False
    
    def send_heartbeat(self):
        """Send heartbeat to ServerPulse"""
        try:
            payload = {
                'agent_id': self.agent_id,
                'timestamp': datetime.utcnow().isoformat(),
                'status': 'online'
            }
            
            response = self._make_request(
                'POST',
                f'{self.endpoint}/api/v1/agents/{self.agent_id}/heartbeat',
                data=payload
            )
            
            if response and response.status_code in [200, 201]:
                if self.logger:
                    self.logger.debug("Heartbeat sent successfully")
                return True
            else:
                if self.logger:
                    self.logger.warning(f"Failed to send heartbeat: {response.status_code if response else 'No response'}")
                return False
                
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error sending heartbeat: {e}")
            return False
    
    def send_alert(self, alert_data):
        """Send alert to ServerPulse"""
        try:
            payload = {
                'agent_id': self.agent_id,
                'timestamp': datetime.utcnow().isoformat(),
                'alert': alert_data
            }
            
            response = self._make_request(
                'POST',
                f'{self.endpoint}/api/v1/agents/{self.agent_id}/alerts',
                data=payload
            )
            
            if response and response.status_code in [200, 201]:
                if self.logger:
                    self.logger.info(f"Alert sent: {alert_data.get('type', 'unknown')}")
                return True
            else:
                if self.logger:
                    self.logger.warning(f"Failed to send alert: {response.status_code if response else 'No response'}")
                return False
                
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error sending alert: {e}")
            return False
    
    def get_commands(self):
        """Get pending commands from ServerPulse"""
        try:
            response = self._make_request(
                'GET',
                f'{self.endpoint}/api/v1/agents/{self.agent_id}/commands'
            )
            
            if response and response.status_code == 200:
                return response.json().get('commands', [])
            else:
                if self.logger:
                    self.logger.warning(f"Failed to get commands: {response.status_code if response else 'No response'}")
                return []
                
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error getting commands: {e}")
            return []
    
    def acknowledge_command(self, command_id, result):
        """Acknowledge command execution"""
        try:
            payload = {
                'command_id': command_id,
                'result': result,
                'timestamp': datetime.utcnow().isoformat()
            }
            
            response = self._make_request(
                'POST',
                f'{self.endpoint}/api/v1/agents/{self.agent_id}/commands/{command_id}/ack',
                data=payload
            )
            
            if response and response.status_code in [200, 201]:
                if self.logger:
                    self.logger.debug(f"Command {command_id} acknowledged")
                return True
            else:
                if self.logger:
                    self.logger.warning(f"Failed to acknowledge command: {response.status_code if response else 'No response'}")
                return False
                
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error acknowledging command: {e}")
            return False
    
    def _make_request(self, method, url, data=None, retries=None):
        """Make HTTP request with retry logic"""
        if retries is None:
            retries = self.max_retries
        
        for attempt in range(retries + 1):
            try:
                if data:
                    response = self.session.request(
                        method,
                        url,
                        json=data,
                        timeout=self.timeout
                    )
                else:
                    response = self.session.request(
                        method,
                        url,
                        timeout=self.timeout
                    )
                
                # Log response for debugging
                if self.logger and response.status_code >= 400:
                    self.logger.debug(f"API request failed: {method} {url} -> {response.status_code}")
                    if response.text:
                        self.logger.debug(f"Response: {response.text}")
                
                return response
                
            except requests.exceptions.Timeout:
                if self.logger:
                    self.logger.warning(f"Request timeout (attempt {attempt + 1}/{retries + 1}): {url}")
            except requests.exceptions.ConnectionError as e:
                if self.logger:
                    self.logger.warning(f"Connection error (attempt {attempt + 1}/{retries + 1}): {e}")
            except requests.exceptions.RequestException as e:
                if self.logger:
                    self.logger.error(f"Request error (attempt {attempt + 1}/{retries + 1}): {e}")
            except Exception as e:
                if self.logger:
                    self.logger.error(f"Unexpected error (attempt {attempt + 1}/{retries + 1}): {e}")
            
            # Wait before retry (exponential backoff)
            if attempt < retries:
                wait_time = 2 ** attempt
                if self.logger:
                    self.logger.debug(f"Retrying in {wait_time} seconds...")
                time.sleep(wait_time)
        
        if self.logger:
            self.logger.error(f"All retry attempts failed for: {method} {url}")
        return None
    
    def test_connection(self):
        """Test connection to ServerPulse"""
        try:
            response = self._make_request(
                'GET',
                f'{self.endpoint}/api/v1/health',
                retries=1
            )
            
            if response and response.status_code == 200:
                if self.logger:
                    self.logger.info("Connection to ServerPulse successful")
                return True
            else:
                if self.logger:
                    self.logger.error("Failed to connect to ServerPulse")
                return False
                
        except Exception as e:
            if self.logger:
                self.logger.error(f"Error testing connection: {e}")
            return False
