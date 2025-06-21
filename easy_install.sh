#!/bin/bash

# ServerPulse Agent - Fixed Ubuntu Installation Script
# Handles externally managed Python environments and ensures proper startup/shutdown

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/serverpulse-agent"
CONFIG_DIR="/etc/serverpulse-agent"
LOG_DIR="/var/log"
SERVICE_NAME="serverpulse-agent"
AGENT_USER="serverpulse"

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  ServerPulse Agent - Ubuntu Fixed Installer   ${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run with sudo${NC}"
   echo "Usage: sudo ./easy_install.sh"
   exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo -e "${BLUE}Installing from: $SCRIPT_DIR${NC}"

# Function to print step headers
print_step() {
    echo ""
    echo -e "${YELLOW}$1${NC}"
    echo "=========================================="
}

# Step 1: Update system and install dependencies
print_step "Step 1: Installing system dependencies"
apt-get update -qq > /dev/null 2>&1
apt-get install -y python3-full python3-pip python3-venv systemd curl wget git > /dev/null 2>&1
echo -e "${GREEN}✓ System dependencies installed${NC}"

# Step 2: Remove old installation if exists
print_step "Step 2: Cleaning up old installation"
if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
    systemctl stop $SERVICE_NAME
    echo -e "${GREEN}✓ Stopped existing service${NC}"
fi

if systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
    systemctl disable $SERVICE_NAME > /dev/null 2>&1
    echo -e "${GREEN}✓ Disabled existing service${NC}"
fi

if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo -e "${GREEN}✓ Removed old installation${NC}"
fi

# Step 3: Create user and directories
print_step "Step 3: Creating user and directories"
if ! id "$AGENT_USER" &>/dev/null; then
    useradd --system --no-create-home --shell /bin/false --home-dir $INSTALL_DIR $AGENT_USER
    echo -e "${GREEN}✓ Created user: $AGENT_USER${NC}"
else
    echo -e "${GREEN}✓ User $AGENT_USER already exists${NC}"
fi

# Create directories
mkdir -p $INSTALL_DIR
mkdir -p $CONFIG_DIR
mkdir -p $LOG_DIR
echo -e "${GREEN}✓ Directories created${NC}"

# Step 4: Copy agent files and create virtual environment
print_step "Step 4: Setting up agent and Python environment"
cp -r $SCRIPT_DIR/* $INSTALL_DIR/ 2>/dev/null || true

# Create virtual environment using python3-full
cd $INSTALL_DIR
python3 -m venv --system-site-packages venv
echo -e "${GREEN}✓ Virtual environment created${NC}"

# Activate venv and install packages
source venv/bin/activate

# Create clean requirements.txt
cat > requirements.txt << 'EOF'
psutil>=5.9.0
requests>=2.28.0
pyyaml>=6.0
schedule>=1.2.0
websocket-client>=1.4.0
setproctitle>=1.3.0
EOF

# Install packages in virtual environment
venv/bin/pip install --upgrade pip > /dev/null 2>&1
venv/bin/pip install -r requirements.txt > /dev/null 2>&1
echo -e "${GREEN}✓ Python packages installed in virtual environment${NC}"

# Step 5: Create the main agent script if it doesn't exist
if [ ! -f "$INSTALL_DIR/serverpulse_agent.py" ]; then
    print_step "Step 5: Creating agent script"
    cat > "$INSTALL_DIR/serverpulse_agent.py" << 'EOF'
#!/usr/bin/env python3
"""
ServerPulse Agent - Ubuntu Monitoring Agent
"""
import os
import sys
import time
import json
import logging
import signal
import threading
import traceback
from datetime import datetime
from pathlib import Path
import psutil
import requests
import yaml
import schedule
from setproctitle import setproctitle

class ServerPulseAgent:
    def __init__(self, config_path="/etc/serverpulse-agent/config.yml"):
        self.config_path = config_path
        self.config = {}
        self.running = False
        self.logger = None
        self.api_client = None
        self.setup_logging()
        self.load_config()
        
    def setup_logging(self):
        """Setup logging"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/var/log/serverpulse-agent.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('serverpulse-agent')
        
    def load_config(self):
        """Load configuration"""
        try:
            if Path(self.config_path).exists():
                with open(self.config_path, 'r') as f:
                    self.config = yaml.safe_load(f) or {}
            else:
                self.logger.error(f"Config file not found: {self.config_path}")
                sys.exit(1)
        except Exception as e:
            self.logger.error(f"Error loading config: {e}")
            sys.exit(1)
            
    def collect_metrics(self):
        """Collect system metrics"""
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()
            
            # Memory metrics
            memory = psutil.virtual_memory()
            swap = psutil.swap_memory()
            
            # Disk metrics
            disk_usage = {}
            for partition in psutil.disk_partitions():
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    disk_usage[partition.mountpoint] = {
                        'total': usage.total,
                        'used': usage.used,
                        'free': usage.free,
                        'percent': (usage.used / usage.total * 100) if usage.total > 0 else 0
                    }
                except:
                    continue
            
            # Network metrics
            network = psutil.net_io_counters()
            
            # System info
            boot_time = psutil.boot_time()
            uptime = time.time() - boot_time
            
            # Load average
            try:
                load_avg = os.getloadavg()
                load_average = {'1min': load_avg[0], '5min': load_avg[1], '15min': load_avg[2]}
            except:
                load_average = {}
            
            metrics = {
                'timestamp': datetime.utcnow().isoformat(),
                'hostname': os.uname().nodename,
                'cpu': {
                    'usage_percent': cpu_percent,
                    'count': cpu_count
                },
                'memory': {
                    'total': memory.total,
                    'used': memory.used,
                    'available': memory.available,
                    'percent': memory.percent
                },
                'swap': {
                    'total': swap.total,
                    'used': swap.used,
                    'percent': swap.percent
                },
                'disk': disk_usage,
                'network': {
                    'bytes_sent': network.bytes_sent,
                    'bytes_recv': network.bytes_recv,
                    'packets_sent': network.packets_sent,
                    'packets_recv': network.packets_recv
                },
                'uptime': uptime,
                'load_average': load_average
            }
            
            return metrics
        except Exception as e:
            self.logger.error(f"Error collecting metrics: {e}")
            return {}
    
    def send_to_serverpulse(self, endpoint, data):
        """Send data to ServerPulse"""
        try:
            server_url = self.config.get('server', {}).get('endpoint', '')
            auth_token = self.config.get('server', {}).get('auth_token', '')
            
            if not server_url or not auth_token:
                self.logger.error("Missing server URL or auth token in config")
                return False
            
            url = f"{server_url.rstrip('/')}/{endpoint.lstrip('/')}"
            headers = {
                'Authorization': f'Bearer {auth_token}',
                'Content-Type': 'application/json'
            }
            
            response = requests.post(url, json=data, headers=headers, timeout=30)
            
            if response.status_code in [200, 201]:
                self.logger.debug(f"Successfully sent to {endpoint}")
                return True
            else:
                self.logger.warning(f"Failed to send to {endpoint}: {response.status_code}")
                return False
                
        except requests.exceptions.ConnectionError:
            self.logger.error(f"Connection error to ServerPulse at {server_url}")
            return False
        except Exception as e:
            self.logger.error(f"Error sending to ServerPulse: {e}")
            return False
    
    def register_agent(self):
        """Register agent with ServerPulse"""
        try:
            uname = os.uname()
            agent_data = {
                'agent_id': self.config.get('server', {}).get('agent_id', f"{uname.nodename}-{int(time.time())}"),
                'hostname': uname.nodename,
                'system': uname.sysname,
                'release': uname.release,
                'version': uname.version,
                'machine': uname.machine
            }
            
            return self.send_to_serverpulse('agents/register', agent_data)
        except Exception as e:
            self.logger.error(f"Error registering agent: {e}")
            return False
    
    def send_metrics(self):
        """Send metrics to ServerPulse"""
        try:
            metrics = self.collect_metrics()
            if metrics:
                agent_id = self.config.get('server', {}).get('agent_id', 'unknown')
                data = {
                    'agent_id': agent_id,
                    'timestamp': datetime.utcnow().isoformat(),
                    'metrics': metrics
                }
                return self.send_to_serverpulse(f'agents/{agent_id}/metrics', data)
            return False
        except Exception as e:
            self.logger.error(f"Error sending metrics: {e}")
            return False
    
    def send_heartbeat(self):
        """Send heartbeat to ServerPulse"""
        try:
            agent_id = self.config.get('server', {}).get('agent_id', 'unknown')
            data = {
                'agent_id': agent_id,
                'timestamp': datetime.utcnow().isoformat(),
                'status': 'online'
            }
            return self.send_to_serverpulse(f'agents/{agent_id}/heartbeat', data)
        except Exception as e:
            self.logger.error(f"Error sending heartbeat: {e}")
            return False
    
    def send_offline_status(self):
        """Send offline status to ServerPulse"""
        try:
            agent_id = self.config.get('server', {}).get('agent_id', 'unknown')
            data = {
                'agent_id': agent_id,
                'timestamp': datetime.utcnow().isoformat(),
                'status': 'offline'
            }
            self.send_to_serverpulse(f'agents/{agent_id}/heartbeat', data)
            self.logger.info("Sent offline status to ServerPulse")
        except Exception as e:
            self.logger.error(f"Error sending offline status: {e}")
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        self.send_offline_status()
    
    def start(self):
        """Start the agent"""
        try:
            # Set process title
            setproctitle("serverpulse-agent")
            
            # Setup signal handlers
            signal.signal(signal.SIGTERM, self.signal_handler)
            signal.signal(signal.SIGINT, self.signal_handler)
            
            self.logger.info("Starting ServerPulse Agent...")
            
            # Register agent
            if not self.register_agent():
                self.logger.error("Failed to register agent")
                return
            
            self.logger.info("Agent registered successfully")
            self.running = True
            
            # Schedule tasks
            interval = self.config.get('collection', {}).get('interval', 30)
            schedule.every(interval).seconds.do(self.send_metrics)
            schedule.every(60).seconds.do(self.send_heartbeat)
            
            # Send initial metrics
            self.send_metrics()
            
            # Main loop
            while self.running:
                schedule.run_pending()
                time.sleep(1)
                
        except Exception as e:
            self.logger.error(f"Fatal error: {e}")
            self.logger.error(traceback.format_exc())
        finally:
            self.send_offline_status()
            self.logger.info("Agent stopped")

def main():
    """Main entry point"""
    config_path = "/etc/serverpulse-agent/config.yml"
    if len(sys.argv) > 1:
        config_path = sys.argv[1]
    
    agent = ServerPulseAgent(config_path)
    agent.start()

if __name__ == "__main__":
    main()
EOF
    chmod +x "$INSTALL_DIR/serverpulse_agent.py"
    echo -e "${GREEN}✓ Agent script created${NC}"
fi

# Step 6: Create systemd service with proper shutdown handling
print_step "Step 6: Creating systemd service"
cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=ServerPulse Monitoring Agent
Documentation=https://docs.serverpulse.com
After=network.target
Wants=network.target

[Service]
Type=simple
User=$AGENT_USER
Group=$AGENT_USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin:\$PATH
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/serverpulse_agent.py $CONFIG_DIR/config.yml
ExecStop=/bin/kill -TERM \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
TimeoutStopSec=30
KillMode=mixed
KillSignal=SIGTERM

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$LOG_DIR $CONFIG_DIR /tmp

[Install]
WantedBy=multi-user.target
EOF

echo -e "${GREEN}✓ Systemd service created${NC}"

# Step 7: Set permissions
print_step "Step 7: Setting permissions"
chown -R $AGENT_USER:$AGENT_USER $INSTALL_DIR
chown -R $AGENT_USER:$AGENT_USER $CONFIG_DIR
chmod +x $INSTALL_DIR/serverpulse_agent.py
echo -e "${GREEN}✓ Permissions set${NC}"

# Step 8: Create configuration file
print_step "Step 8: Creating configuration"
if [ ! -f $CONFIG_DIR/config.yml ]; then
    cat > $CONFIG_DIR/config.yml << EOF
server:
  # CHANGE THIS: Your ServerPulse URL (e.g., http://192.168.1.100:80/api/v1)
  endpoint: "http://YOUR_SERVERPULSE_IP/api/v1"
  
  # CHANGE THIS: Your authentication token
  auth_token: "your-auth-token-here"
  
  # Unique agent identifier
  agent_id: "$(hostname)-$(date +%s)"

collection:
  interval: 30  # seconds

alerts:
  cpu_threshold: 80
  memory_threshold: 85
  disk_threshold: 90

logging:
  level: INFO
  file: /var/log/serverpulse-agent.log
EOF
    
    chown $AGENT_USER:$AGENT_USER $CONFIG_DIR/config.yml
    chmod 600 $CONFIG_DIR/config.yml
    echo -e "${GREEN}✓ Configuration file created${NC}"
else
    echo -e "${GREEN}✓ Configuration file already exists${NC}"
fi

# Step 9: Enable service for auto-start
print_step "Step 9: Configuring auto-start"
systemctl daemon-reload
systemctl enable $SERVICE_NAME > /dev/null 2>&1
echo -e "${GREEN}✓ Service enabled for auto-start on boot${NC}"

# Step 10: Interactive configuration
print_step "Step 10: Configuration setup"
echo -e "${BLUE}Please provide your ServerPulse details:${NC}"
echo ""

VM_IP=$(hostname -I | awk '{print $1}')
echo -e "${BLUE}Your VM IP address: $VM_IP${NC}"
echo ""

read -p "Enter your ServerPulse URL (e.g., http://192.168.1.100:80): " SERVERPULSE_URL
read -p "Enter your authentication token: " AUTH_TOKEN

if [ -n "$SERVERPULSE_URL" ] && [ -n "$AUTH_TOKEN" ]; then
    # Update configuration
    sed -i "s|http://YOUR_SERVERPULSE_IP/api/v1|$SERVERPULSE_URL/api/v1|g" $CONFIG_DIR/config.yml
    sed -i "s|your-auth-token-here|$AUTH_TOKEN|g" $CONFIG_DIR/config.yml
    echo -e "${GREEN}✓ Configuration updated${NC}"
    
    # Start the service
    echo ""
    echo -e "${YELLOW}Starting ServerPulse Agent...${NC}"
    systemctl start $SERVICE_NAME
    sleep 3
    
    # Check status
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✓ Agent started successfully and is monitoring!${NC}"
        echo ""
        echo -e "${BLUE}Agent Status:${NC}"
        systemctl status $SERVICE_NAME --no-pager -l
    else
        echo -e "${RED}⚠ Agent failed to start. Checking logs...${NC}"
        echo ""
        journalctl -u $SERVICE_NAME --no-pager -l
    fi
else
    echo -e "${YELLOW}⚠ Configuration not completed. Please configure manually:${NC}"
    echo "  sudo nano $CONFIG_DIR/config.yml"
    echo "  sudo systemctl start $SERVICE_NAME"
fi

# Final instructions
echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}         Installation Complete!                     ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo -e "${BLUE}✓ Agent installed and configured for auto-start${NC}"
echo -e "${BLUE}✓ Monitors: CPU, Memory, Disk, Network, Services${NC}"
echo -e "${BLUE}✓ Sends offline status on shutdown${NC}"
echo -e "${BLUE}✓ Auto-restarts if it crashes${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC} $CONFIG_DIR/config.yml"
echo -e "${BLUE}Logs:${NC} /var/log/serverpulse-agent.log"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  Check status:    sudo systemctl status $SERVICE_NAME"
echo "  View logs:       sudo journalctl -u $SERVICE_NAME -f"
echo "  Restart:         sudo systemctl restart $SERVICE_NAME"
echo "  Stop:            sudo systemctl stop $SERVICE_NAME"
echo ""
echo -e "${GREEN}Your server is now being monitored by ServerPulse!${NC}"
echo -e "${GREEN}The agent will start automatically on every boot.${NC}"
