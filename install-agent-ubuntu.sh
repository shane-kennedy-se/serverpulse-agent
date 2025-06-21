#!/bin/bash
# ServerPulse Agent Installation Script for Ubuntu (Fixed for externally managed Python)

echo "🚀 Installing ServerPulse Agent on Ubuntu..."

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "Cannot detect OS. This script is for Ubuntu/Debian systems."
    exit 1
fi

echo "Detected OS: $OS"

# Update system packages
echo "📦 Updating system packages..."
sudo apt update

# Install required system packages including python3-full
echo "🔧 Installing required system packages..."
sudo apt install -y python3 python3-pip python3-venv python3-full curl wget unzip systemd git

# Create application directory
echo "📁 Creating application directory..."
sudo mkdir -p /opt/serverpulse-agent
sudo mkdir -p /etc/serverpulse-agent
sudo mkdir -p /var/log/serverpulse-agent

# Download the agent (we'll create a simple agent since the GitHub repo might not exist)
echo "⬇️ Creating ServerPulse agent..."
cd /tmp

# Create a simple agent implementation
cat > serverpulse_agent.py << 'EOF'
#!/usr/bin/env python3
"""
ServerPulse Monitoring Agent
A simple monitoring agent that collects system metrics and sends them to ServerPulse.
"""

import json
import time
import sys
import os
import psutil
import requests
import yaml
import socket
import platform
from datetime import datetime
import logging
import signal
import subprocess

class ServerPulseAgent:
    def __init__(self, config_file):
        self.config = self.load_config(config_file)
        self.agent_id = None
        self.auth_token = None
        self.running = True
        self.setup_logging()
        
        # Setup signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def setup_logging(self):
        log_level = getattr(logging, self.config.get('logging', {}).get('level', 'INFO'))
        log_file = self.config.get('logging', {}).get('file', '/var/log/serverpulse-agent/agent.log')
        
        # Create log directory if it doesn't exist
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
        
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def signal_handler(self, signum, frame):
        self.logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False
    
    def load_config(self, config_file):
        try:
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        except Exception as e:
            print(f"Error loading config: {e}")
            sys.exit(1)
    
    def get_system_info(self):
        return {
            'hostname': socket.gethostname(),
            'platform': platform.platform(),
            'architecture': platform.architecture()[0],
            'processor': platform.processor(),
            'python_version': platform.python_version()
        }
    
    def register_agent(self):
        """Register this agent with the ServerPulse server"""
        endpoint = f"{self.config['server']['endpoint'].rstrip('/')}/api/v1/agents/register"
        
        # Get local IP address
        try:
            # Connect to a remote server to get the local IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
        except:
            local_ip = "127.0.0.1"
        
        registration_data = {
            'server_ip': local_ip,
            'hostname': socket.gethostname(),
            'agent_version': '1.0.0',
            'system_info': self.get_system_info()
        }
        
        try:
            response = requests.post(endpoint, json=registration_data, timeout=30)
            if response.status_code == 200:
                data = response.json()
                if data.get('success'):
                    self.agent_id = data['agent_id']
                    self.auth_token = data['auth_token']
                    self.logger.info(f"Successfully registered with agent ID: {self.agent_id}")
                    
                    # Update config file with agent details
                    self.update_config_with_agent_details()
                    return True
            
            self.logger.error(f"Registration failed: {response.status_code} - {response.text}")
            return False
        except Exception as e:
            self.logger.error(f"Registration error: {e}")
            return False
    
    def update_config_with_agent_details(self):
        """Update the config file with agent ID and token"""
        config_file = '/etc/serverpulse-agent/config.yml'
        try:
            with open(config_file, 'r') as f:
                config = yaml.safe_load(f)
            
            config['server']['agent_id'] = self.agent_id
            config['server']['auth_token'] = self.auth_token
            
            with open(config_file, 'w') as f:
                yaml.dump(config, f, default_flow_style=False)
            
            self.logger.info("Config file updated with agent details")
        except Exception as e:
            self.logger.error(f"Failed to update config: {e}")
    
    def collect_metrics(self):
        """Collect system metrics"""
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=1)
            
            # Memory metrics
            memory = psutil.virtual_memory()
            
            # Disk metrics
            disk = psutil.disk_usage('/')
            
            # Network metrics
            network = psutil.net_io_counters()
            
            # System uptime
            uptime = time.time() - psutil.boot_time()
            
            # Load average
            load_avg = os.getloadavg()[0] if hasattr(os, 'getloadavg') else 0
            
            return {
                'cpu_usage': cpu_percent,
                'memory_usage': memory.percent,
                'disk_usage': disk.percent,
                'uptime': uptime,
                'load_average': load_avg,
                'network_rx': network.bytes_recv,
                'network_tx': network.bytes_sent,
                'disk_io_read': 0,  # Can be enhanced
                'disk_io_write': 0  # Can be enhanced
            }
        except Exception as e:
            self.logger.error(f"Error collecting metrics: {e}")
            return None
    
    def collect_services(self):
        """Collect service status information"""
        services = self.config.get('monitoring', {}).get('services', [])
        service_status = []
        
        for service in services:
            try:
                result = subprocess.run(['systemctl', 'is-active', service], 
                                      capture_output=True, text=True)
                status = 'active' if result.returncode == 0 else 'inactive'
                service_status.append({'name': service, 'status': status})
            except Exception as e:
                self.logger.warning(f"Could not check service {service}: {e}")
                service_status.append({'name': service, 'status': 'unknown'})
        
        return service_status
    
    def send_metrics(self, metrics, services):
        """Send metrics to ServerPulse"""
        if not self.agent_id or not self.auth_token:
            self.logger.error("Agent not registered, cannot send metrics")
            return False
        
        endpoint = f"{self.config['server']['endpoint'].rstrip('/')}/api/v1/agents/{self.agent_id}/metrics"
        
        data = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'metrics': metrics,
            'services': services
        }
        
        headers = {
            'Authorization': f'Bearer {self.auth_token}',
            'Content-Type': 'application/json'
        }
        
        try:
            response = requests.post(endpoint, json=data, headers=headers, timeout=30)
            if response.status_code == 200:
                self.logger.debug("Metrics sent successfully")
                return True
            else:
                self.logger.error(f"Failed to send metrics: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            self.logger.error(f"Error sending metrics: {e}")
            return False
    
    def send_heartbeat(self):
        """Send heartbeat to ServerPulse"""
        if not self.agent_id or not self.auth_token:
            return False
        
        endpoint = f"{self.config['server']['endpoint'].rstrip('/')}/api/v1/agents/{self.agent_id}/heartbeat"
        
        headers = {
            'Authorization': f'Bearer {self.auth_token}',
            'Content-Type': 'application/json'
        }
        
        try:
            response = requests.post(endpoint, json={}, headers=headers, timeout=30)
            return response.status_code == 200
        except Exception as e:
            self.logger.error(f"Error sending heartbeat: {e}")
            return False
    
    def run(self):
        """Main agent loop"""
        self.logger.info("Starting ServerPulse Agent...")
        
        # Try to use existing credentials from config
        if self.config['server'].get('agent_id') and self.config['server'].get('auth_token'):
            if self.config['server']['agent_id'] != 'WILL_BE_GENERATED_AFTER_REGISTRATION':
                self.agent_id = self.config['server']['agent_id']
                self.auth_token = self.config['server']['auth_token']
                self.logger.info("Using existing agent credentials")
        
        # Register if not already registered
        if not self.agent_id or not self.auth_token:
            self.logger.info("Registering agent...")
            if not self.register_agent():
                self.logger.error("Failed to register agent, exiting")
                return
        
        collection_interval = self.config.get('collection', {}).get('interval', 30)
        heartbeat_interval = 60  # Send heartbeat every minute
        last_heartbeat = 0
        
        self.logger.info(f"Agent started. Collection interval: {collection_interval}s")
        
        while self.running:
            try:
                # Collect and send metrics
                metrics = self.collect_metrics()
                services = self.collect_services()
                
                if metrics:
                    self.send_metrics(metrics, services)
                
                # Send heartbeat if needed
                current_time = time.time()
                if current_time - last_heartbeat >= heartbeat_interval:
                    self.send_heartbeat()
                    last_heartbeat = current_time
                
                # Wait for next collection
                time.sleep(collection_interval)
                
            except KeyboardInterrupt:
                self.logger.info("Received interrupt signal, shutting down...")
                break
            except Exception as e:
                self.logger.error(f"Unexpected error in main loop: {e}")
                time.sleep(10)  # Wait before retrying
        
        self.logger.info("ServerPulse Agent stopped")

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 serverpulse_agent.py <config_file>")
        sys.exit(1)
    
    config_file = sys.argv[1]
    if not os.path.exists(config_file):
        print(f"Config file not found: {config_file}")
        sys.exit(1)
    
    agent = ServerPulseAgent(config_file)
    agent.run()

if __name__ == '__main__':
    main()
EOF

# Create requirements.txt
cat > requirements.txt << 'EOF'
requests>=2.25.0
psutil>=5.8.0
PyYAML>=6.0
EOF

# Create virtual environment to avoid external environment error
echo "🐍 Creating Python virtual environment..."
sudo python3 -m venv /opt/serverpulse-agent/venv

# Install Python dependencies in virtual environment
echo "📋 Installing Python dependencies..."
sudo /opt/serverpulse-agent/venv/bin/pip install --upgrade pip
sudo /opt/serverpulse-agent/venv/bin/pip install -r requirements.txt

# Copy agent files
echo "📄 Copying agent files..."
sudo cp serverpulse_agent.py /opt/serverpulse-agent/
sudo cp requirements.txt /opt/serverpulse-agent/
sudo chmod +x /opt/serverpulse-agent/*.py

# Create agent user
echo "👤 Creating serverpulse user..."
sudo useradd -r -s /bin/false serverpulse 2>/dev/null || true

# Set permissions
echo "🔐 Setting permissions..."
sudo chown -R serverpulse:serverpulse /opt/serverpulse-agent
sudo chown -R serverpulse:serverpulse /etc/serverpulse-agent
sudo chown -R serverpulse:serverpulse /var/log/serverpulse-agent

# Create systemd service with virtual environment
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/serverpulse-agent.service > /dev/null <<EOF
[Unit]
Description=ServerPulse Monitoring Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=serverpulse
Group=serverpulse
WorkingDirectory=/opt/serverpulse-agent
Environment=PATH=/opt/serverpulse-agent/venv/bin
ExecStart=/opt/serverpulse-agent/venv/bin/python /opt/serverpulse-agent/serverpulse_agent.py /etc/serverpulse-agent/config.yml
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=serverpulse-agent

[Install]
WantedBy=multi-user.target
EOF

# Get server IP
SERVER_IP=\$(hostname -I | awk '{print \$1}')

# Create configuration file
echo "📝 Creating configuration file..."
sudo tee /etc/serverpulse-agent/config.yml > /dev/null <<EOF
server:
  endpoint: "http://your-serverpulse-server.com"  # Update this with your ServerPulse URL
  auth_token: "WILL_BE_GENERATED_AFTER_REGISTRATION"
  agent_id: "WILL_BE_GENERATED_AFTER_REGISTRATION"

collection:
  interval: 30  # Data collection interval in seconds
  metrics:
    - system_stats
    - disk_usage
    - network_stats
    - process_list

monitoring:
  services:
    - ssh
    - nginx
    - apache2
    - mysql
    - docker
    - postgresql

alerts:
  cpu_threshold: 80      # CPU usage percentage
  memory_threshold: 85   # Memory usage percentage
  disk_threshold: 90     # Disk usage percentage
  load_threshold: 5.0    # System load average

logging:
  level: INFO
  file: /var/log/serverpulse-agent/agent.log
EOF

# Set config permissions
sudo chown serverpulse:serverpulse /etc/serverpulse-agent/config.yml
sudo chmod 600 /etc/serverpulse-agent/config.yml

# Reload systemd
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload

echo "✅ ServerPulse Agent installation completed!"
echo ""
echo "📋 Next steps:"
echo "1. Edit the configuration file:"
echo "   sudo nano /etc/serverpulse-agent/config.yml"
echo ""
echo "2. Update the 'endpoint' to point to your ServerPulse server"
echo "   Example: http://your-domain.com or http://your-server-ip:8000"
echo ""
echo "3. Start the agent:"
echo "   sudo systemctl enable serverpulse-agent"
echo "   sudo systemctl start serverpulse-agent"
echo ""
echo "4. Check status:"
echo "   sudo systemctl status serverpulse-agent"
echo ""
echo "5. View logs:"
echo "   sudo journalctl -u serverpulse-agent -f"
echo ""
echo "🔍 Server IP detected as: \$SERVER_IP"
echo "Make sure this server is added to ServerPulse with this IP address."
