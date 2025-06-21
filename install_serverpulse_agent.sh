#!/bin/bash

# ServerPulse Agent - Universal Linux Installer
# Single script installation for any Linux distribution
# Handles all dependencies, creates the agent, and configures auto-start

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/opt/serverpulse-agent"
SERVICE_NAME="serverpulse-agent"

echo -e "${GREEN}🚀 ServerPulse Agent Universal Installer${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run with sudo${NC}"
   echo "Usage: sudo bash install_serverpulse_agent.sh"
   exit 1
fi

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}❌ Cannot detect Linux distribution${NC}"
        exit 1
    fi
    echo -e "${BLUE}📍 Detected: $PRETTY_NAME${NC}"
}

# Install dependencies based on distribution
install_dependencies() {
    echo -e "${BLUE}📦 Installing system dependencies...${NC}"
    
    case $DISTRO in
        ubuntu|debian)
            apt-get update -qq > /dev/null 2>&1
            apt-get install -y python3 python3-pip python3-venv python3-dev curl wget systemd > /dev/null 2>&1
            # Handle Ubuntu's externally managed environment
            if command -v python3-full >/dev/null 2>&1; then
                apt-get install -y python3-full > /dev/null 2>&1
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y python3 python3-pip python3-devel curl wget systemd > /dev/null 2>&1
            else
                yum install -y python3 python3-pip python3-devel curl wget systemd > /dev/null 2>&1
            fi
            ;;
        opensuse|sles)
            zypper install -y python3 python3-pip python3-devel curl wget systemd > /dev/null 2>&1
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm python python-pip curl wget systemd > /dev/null 2>&1
            ;;
        *)
            echo -e "${YELLOW}⚠️ Unknown distribution, attempting generic installation...${NC}"
            # Try to install with common package managers
            for pm in apt-get yum dnf zypper pacman; do
                if command -v $pm >/dev/null 2>&1; then
                    case $pm in
                        apt-get) apt-get update -qq && apt-get install -y python3 python3-pip python3-venv curl wget systemd ;;
                        yum|dnf) $pm install -y python3 python3-pip curl wget systemd ;;
                        zypper) zypper install -y python3 python3-pip curl wget systemd ;;
                        pacman) pacman -Sy --noconfirm python python-pip curl wget systemd ;;
                    esac
                    break
                fi
            done
            ;;
    esac
    echo -e "${GREEN}✓ Dependencies installed${NC}"
}

# Create installation directory and virtual environment
setup_environment() {
    echo -e "${BLUE}🗂️ Setting up installation environment...${NC}"
    
    # Stop existing service if running
    if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        systemctl stop $SERVICE_NAME
        echo -e "${GREEN}✓ Stopped existing service${NC}"
    fi
    
    # Remove old installation
    rm -rf $INSTALL_DIR
    mkdir -p $INSTALL_DIR/logs
    cd $INSTALL_DIR
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Upgrade pip and install packages
    pip install --upgrade pip > /dev/null 2>&1
    pip install psutil requests pyyaml schedule > /dev/null 2>&1
    
    echo -e "${GREEN}✓ Environment ready${NC}"
}

# Create the main agent script
create_agent() {
    echo -e "${BLUE}🤖 Creating ServerPulse agent...${NC}"
    
    cat > $INSTALL_DIR/serverpulse_agent.py << 'EOF'
#!/usr/bin/env python3
"""
ServerPulse Agent - Universal Linux Monitoring Agent
Collects system metrics and reports to ServerPulse backend
"""

import os
import sys
import time
import json
import signal
import logging
import threading
import traceback
import subprocess
from datetime import datetime
from pathlib import Path

# Import required modules
import psutil
import requests
import yaml
import schedule

class ServerPulseAgent:
    def __init__(self):
        self.config_file = "/opt/serverpulse-agent/config.yml"
        self.config = {}
        self.running = False
        self.logger = self.setup_logging()
        self.load_config()
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        
    def setup_logging(self):
        """Setup logging configuration"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler('/opt/serverpulse-agent/logs/agent.log'),
                logging.StreamHandler()
            ]
        )
        return logging.getLogger('serverpulse-agent')
        
    def load_config(self):
        """Load configuration from file"""
        try:
            if os.path.exists(self.config_file):
                with open(self.config_file, 'r') as f:
                    self.config = yaml.safe_load(f) or {}
                self.logger.info("Configuration loaded successfully")
            else:
                self.logger.error(f"Config file not found: {self.config_file}")
                self.create_default_config()
        except Exception as e:
            self.logger.error(f"Error loading config: {e}")
            self.create_default_config()
            
    def create_default_config(self):
        """Create default configuration file"""
        default_config = {
            'api_endpoint': 'http://localhost:8000/api',
            'api_key': '',
            'server_id': f"{os.uname().nodename}-{int(time.time())}",
            'collection_interval': 30,
            'heartbeat_interval': 60,
            'api_timeout': 30,
            'log_level': 'INFO'
        }
        
        try:
            with open(self.config_file, 'w') as f:
                yaml.dump(default_config, f, default_flow_style=False)
            self.config = default_config
            self.logger.info("Created default configuration file")
        except Exception as e:
            self.logger.error(f"Error creating config file: {e}")
            
    def collect_system_metrics(self):
        """Collect comprehensive system metrics"""
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
                except PermissionError:
                    continue
            
            # Network metrics
            network = psutil.net_io_counters()
            
            # System info
            boot_time = psutil.boot_time()
            uptime = time.time() - boot_time
            
            # Load average (Linux only)
            try:
                load_avg = os.getloadavg()
                load_average = {'1min': load_avg[0], '5min': load_avg[1], '15min': load_avg[2]}
            except (OSError, AttributeError):
                load_average = {}
            
            # Process count
            process_count = len(psutil.pids())
            
            return {
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
                'load_average': load_average,
                'process_count': process_count
            }
            
        except Exception as e:
            self.logger.error(f"Error collecting metrics: {e}")
            return {}
    
    def check_services(self):
        """Check status of common services"""
        services = ['apache2', 'nginx', 'mysql', 'postgresql', 'redis-server', 'docker', 'ssh']
        service_status = {}
        
        for service in services:
            try:
                result = subprocess.run(['systemctl', 'is-active', service], 
                                      capture_output=True, text=True, timeout=5)
                service_status[service] = {
                    'active': result.returncode == 0,
                    'status': result.stdout.strip()
                }
            except:
                service_status[service] = {'active': False, 'status': 'unknown'}
                
        return service_status
    
    def send_to_serverpulse(self, endpoint, data):
        """Send data to ServerPulse backend"""
        try:
            api_endpoint = self.config.get('api_endpoint', '').rstrip('/')
            api_key = self.config.get('api_key', '')
            server_id = self.config.get('server_id', 'unknown')
            
            if not api_endpoint:
                self.logger.error("No API endpoint configured")
                return False
            
            url = f"{api_endpoint}/{endpoint.lstrip('/')}"
            headers = {'Content-Type': 'application/json'}
            
            if api_key:
                headers['Authorization'] = f'Bearer {api_key}'
            
            # Add server_id to data
            data['server_id'] = server_id
            
            response = requests.post(url, json=data, headers=headers, 
                                   timeout=self.config.get('api_timeout', 30))
            
            if response.status_code in [200, 201]:
                self.logger.debug(f"Successfully sent to {endpoint}")
                return True
            else:
                self.logger.warning(f"Failed to send to {endpoint}: HTTP {response.status_code}")
                return False
                
        except requests.exceptions.ConnectionError:
            self.logger.error(f"Connection error to {api_endpoint}")
            return False
        except Exception as e:
            self.logger.error(f"Error sending to ServerPulse: {e}")
            return False
    
    def send_metrics(self):
        """Collect and send metrics"""
        try:
            metrics = self.collect_system_metrics()
            services = self.check_services()
            
            if metrics:
                data = {
                    'timestamp': datetime.utcnow().isoformat(),
                    'metrics': metrics,
                    'services': services
                }
                
                server_id = self.config.get('server_id', 'unknown')
                return self.send_to_serverpulse(f'servers/{server_id}/metrics', data)
            return False
        except Exception as e:
            self.logger.error(f"Error in send_metrics: {e}")
            return False
    
    def send_heartbeat(self):
        """Send heartbeat to ServerPulse"""
        try:
            data = {
                'timestamp': datetime.utcnow().isoformat(),
                'status': 'online',
                'hostname': os.uname().nodename
            }
            
            server_id = self.config.get('server_id', 'unknown')
            return self.send_to_serverpulse(f'servers/{server_id}/heartbeat', data)
        except Exception as e:
            self.logger.error(f"Error sending heartbeat: {e}")
            return False
    
    def send_offline_status(self):
        """Send offline status before shutdown"""
        try:
            data = {
                'timestamp': datetime.utcnow().isoformat(),
                'status': 'offline',
                'hostname': os.uname().nodename
            }
            
            server_id = self.config.get('server_id', 'unknown')
            self.send_to_serverpulse(f'servers/{server_id}/status', data)
            self.logger.info("Sent offline status to ServerPulse")
        except Exception as e:
            self.logger.error(f"Error sending offline status: {e}")
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        self.send_offline_status()
    
    def start(self):
        """Start the monitoring agent"""
        try:
            self.logger.info("Starting ServerPulse Agent...")
            self.running = True
            
            # Send initial online status
            self.send_heartbeat()
            
            # Schedule tasks
            interval = self.config.get('collection_interval', 30)
            heartbeat_interval = self.config.get('heartbeat_interval', 60)
            
            schedule.every(interval).seconds.do(self.send_metrics)
            schedule.every(heartbeat_interval).seconds.do(self.send_heartbeat)
            
            # Send initial metrics
            self.send_metrics()
            
            # Main monitoring loop
            while self.running:
                schedule.run_pending()
                time.sleep(1)
                
        except KeyboardInterrupt:
            self.logger.info("Received keyboard interrupt")
        except Exception as e:
            self.logger.error(f"Fatal error: {e}")
            self.logger.error(traceback.format_exc())
        finally:
            self.send_offline_status()
            self.logger.info("ServerPulse Agent stopped")

def main():
    """Main entry point"""
    agent = ServerPulseAgent()
    agent.start()

if __name__ == "__main__":
    main()
EOF

    chmod +x $INSTALL_DIR/serverpulse_agent.py
    echo -e "${GREEN}✓ Agent created${NC}"
}

# Create configuration file
create_config() {
    echo -e "${BLUE}⚙️ Creating configuration...${NC}"
    
    cat > $INSTALL_DIR/config.yml << 'EOF'
# ServerPulse Agent Configuration
# Update these settings to match your ServerPulse server

# API Configuration - CHANGE THESE
api_endpoint: "http://localhost:8000/api"
api_key: ""
server_id: "my-linux-server"

# Collection Settings
collection_interval: 30  # seconds between metric collections
heartbeat_interval: 60   # seconds between heartbeats
api_timeout: 30          # API request timeout

# Logging
log_level: "INFO"
EOF

    echo -e "${GREEN}✓ Configuration created${NC}"
}

# Create systemd service
create_service() {
    echo -e "${BLUE}🔧 Creating systemd service...${NC}"
    
    cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=ServerPulse Monitoring Agent
Documentation=https://serverpulse.io/docs
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin:\$PATH
Environment=PYTHONPATH=$INSTALL_DIR
Environment=PYTHONUNBUFFERED=1
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/serverpulse_agent.py
ExecStop=/bin/sh -c '$INSTALL_DIR/venv/bin/python -c "
import sys, os, yaml, requests
from datetime import datetime
sys.path.insert(0, \"$INSTALL_DIR\")
try:
    with open(\"$INSTALL_DIR/config.yml\", \"r\") as f:
        config = yaml.safe_load(f)
    data = {
        \"timestamp\": datetime.utcnow().isoformat(),
        \"status\": \"offline\",
        \"hostname\": os.uname().nodename,
        \"server_id\": config.get(\"server_id\", \"unknown\")
    }
    api_endpoint = config.get(\"api_endpoint\", \"\").rstrip(\"/\")
    server_id = config.get(\"server_id\", \"unknown\")
    if api_endpoint and server_id:
        url = f\"{api_endpoint}/servers/{server_id}/status\"
        headers = {\"Content-Type\": \"application/json\"}
        api_key = config.get(\"api_key\", \"\")
        if api_key:
            headers[\"Authorization\"] = f\"Bearer {api_key}\"
        requests.post(url, json=data, headers=headers, timeout=10)
        print(\"Offline status sent successfully\")
except Exception as e:
    print(f\"Error sending offline status: {e}\")
"'

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

[Install]
WantedBy=multi-user.target
EOF

    # Set permissions
    chown -R root:root $INSTALL_DIR
    chmod -R 755 $INSTALL_DIR
    
    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME > /dev/null 2>&1
    
    echo -e "${GREEN}✓ Service configured and enabled${NC}"
}

# Create test script
create_test_script() {
    echo -e "${BLUE}🧪 Creating test script...${NC}"
    
    cat > $INSTALL_DIR/test_agent.py << 'EOF'
#!/usr/bin/env python3
"""Test script for ServerPulse Agent"""

import os
import sys
import yaml
import json
import requests
from datetime import datetime

def test_config():
    """Test configuration"""
    print("🔧 Testing configuration...")
    try:
        config_path = '/opt/serverpulse-agent/config.yml'
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        
        if not config.get('api_endpoint'):
            print("❌ api_endpoint not configured")
            return False
        if not config.get('server_id'):
            print("❌ server_id not configured")
            return False
            
        print("✅ Configuration is valid")
        return config
    except Exception as e:
        print(f"❌ Configuration error: {e}")
        return False

def test_metrics():
    """Test metrics collection"""
    print("\n📊 Testing metrics collection...")
    try:
        sys.path.insert(0, '/opt/serverpulse-agent')
        os.chdir('/opt/serverpulse-agent')
        
        # Activate virtual environment
        activate_script = '/opt/serverpulse-agent/venv/bin/activate_this.py'
        if os.path.exists(activate_script):
            exec(open(activate_script).read(), {'__file__': activate_script})
        
        # Import and test
        from serverpulse_agent import ServerPulseAgent
        agent = ServerPulseAgent()
        metrics = agent.collect_system_metrics()
        
        if metrics and 'cpu' in metrics and 'memory' in metrics:
            print("✅ Metrics collection working")
            print(f"   CPU: {metrics['cpu']['usage_percent']:.1f}%")
            print(f"   Memory: {metrics['memory']['percent']:.1f}%")
            return True
        else:
            print("❌ Metrics collection failed")
            return False
    except Exception as e:
        print(f"❌ Metrics test error: {e}")
        return False

def test_api_connection(config):
    """Test API connection"""
    print("\n🌐 Testing API connection...")
    try:
        api_endpoint = config['api_endpoint'].rstrip('/')
        server_id = config['server_id']
        
        test_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'status': 'test',
            'server_id': server_id
        }
        
        headers = {'Content-Type': 'application/json'}
        api_key = config.get('api_key')
        if api_key:
            headers['Authorization'] = f'Bearer {api_key}'
        
        url = f"{api_endpoint}/servers/{server_id}/status"
        response = requests.post(url, json=test_data, headers=headers, timeout=10)
        
        if response.status_code in [200, 201]:
            print("✅ API connection successful")
            return True
        else:
            print(f"❌ API connection failed: HTTP {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ API connection error: {e}")
        return False

def main():
    """Run tests"""
    print("🧪 ServerPulse Agent Test Suite")
    print("=" * 40)
    
    config = test_config()
    if not config:
        return
        
    metrics_ok = test_metrics()
    api_ok = test_api_connection(config)
    
    print("\n" + "=" * 40)
    print("📋 Test Results:")
    print(f"   Configuration: {'✅' if config else '❌'}")
    print(f"   Metrics: {'✅' if metrics_ok else '❌'}")
    print(f"   API Connection: {'✅' if api_ok else '❌'}")
    
    if config and metrics_ok and api_ok:
        print("\n🎉 All tests passed!")
    else:
        print("\n⚠️ Some tests failed. Check configuration and network connectivity.")

if __name__ == "__main__":
    main()
EOF

    chmod +x $INSTALL_DIR/test_agent.py
    echo -e "${GREEN}✓ Test script created${NC}"
}

# Main installation process
main() {
    detect_distro
    install_dependencies
    setup_environment
    create_agent
    create_config
    create_service
    create_test_script
    
    echo ""
    echo -e "${GREEN}🎉 ServerPulse Agent Installation Complete!${NC}"
    echo -e "${GREEN}===========================================${NC}"
    echo ""
    echo -e "${YELLOW}📝 Next Steps:${NC}"
    echo "1. Configure the agent:"
    echo "   sudo nano $INSTALL_DIR/config.yml"
    echo ""
    echo "2. Update these required settings:"
    echo "   - api_endpoint: http://YOUR_SERVERPULSE_SERVER:8000/api"
    echo "   - server_id: unique-name-for-this-server"
    echo "   - api_key: your-api-key (if required)"
    echo ""
    echo "3. Start the agent:"
    echo "   sudo systemctl start $SERVICE_NAME"
    echo ""
    echo "4. Test the installation:"
    echo "   sudo python3 $INSTALL_DIR/test_agent.py"
    echo ""
    echo -e "${BLUE}💡 Useful Commands:${NC}"
    echo "   Status:  sudo systemctl status $SERVICE_NAME"
    echo "   Logs:    sudo journalctl -u $SERVICE_NAME -f"
    echo "   Restart: sudo systemctl restart $SERVICE_NAME"
    echo ""
    echo -e "${GREEN}✅ The agent will start automatically on boot and report offline status on shutdown.${NC}"
}

# Run the installation
main
