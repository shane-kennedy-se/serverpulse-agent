#!/bin/bash

# ServerPulse Agent - Quick Ubuntu Installer
# Simple, reliable installation for Ubuntu VMs

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🚀 ServerPulse Agent Quick Installer${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run with sudo${NC}"
   echo "Usage: sudo ./quick_install.sh"
   exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
INSTALL_DIR="/opt/serverpulse-agent"

echo -e "${BLUE}📦 Installing system dependencies...${NC}"
apt-get update -qq > /dev/null 2>&1
apt-get install -y python3-full python3-pip python3-venv curl wget git systemd > /dev/null 2>&1
echo -e "${GREEN}✓ Dependencies installed${NC}"

echo -e "${BLUE}🗂️ Setting up installation directory...${NC}"
# Clean up old installation
if systemctl is-active --quiet serverpulse-agent 2>/dev/null; then
    systemctl stop serverpulse-agent
fi
if systemctl is-enabled --quiet serverpulse-agent 2>/dev/null; then
    systemctl disable serverpulse-agent > /dev/null 2>&1
fi
rm -rf $INSTALL_DIR
mkdir -p $INSTALL_DIR
echo -e "${GREEN}✓ Directory prepared${NC}"

echo -e "${BLUE}🐍 Creating Python virtual environment...${NC}"
cd $INSTALL_DIR
python3 -m venv venv
source venv/bin/activate

# Create requirements file
cat > requirements.txt << 'EOF'
psutil>=5.9.0
requests>=2.28.0
pyyaml>=6.0
schedule>=1.2.0
EOF

# Install packages
venv/bin/pip install --upgrade pip > /dev/null 2>&1
venv/bin/pip install -r requirements.txt > /dev/null 2>&1
echo -e "${GREEN}✓ Virtual environment ready${NC}"

echo -e "${BLUE}📋 Copying agent files...${NC}"
# Copy all source files
cp -r $SCRIPT_DIR/collectors $INSTALL_DIR/ 2>/dev/null || true
cp -r $SCRIPT_DIR/communication $INSTALL_DIR/ 2>/dev/null || true
cp -r $SCRIPT_DIR/utils $INSTALL_DIR/ 2>/dev/null || true
cp $SCRIPT_DIR/serverpulse_agent.py $INSTALL_DIR/ 2>/dev/null || true
cp $SCRIPT_DIR/requirements.txt $INSTALL_DIR/ 2>/dev/null || true

# Create directories if they don't exist
mkdir -p $INSTALL_DIR/{collectors,communication,utils,logs}
echo -e "${GREEN}✓ Files copied${NC}"

echo -e "${BLUE}⚙️ Creating configuration...${NC}"
cat > $INSTALL_DIR/config.yml << 'EOF'
# ServerPulse Agent Configuration
api_endpoint: "http://localhost:8000/api"
api_key: ""
server_id: "ubuntu-server-1"
collection_interval: 30
heartbeat_interval: 60
api_timeout: 30
log_level: "INFO"

services_to_monitor:
  - apache2
  - nginx
  - mysql
  - postgresql
  - redis-server
  - docker
  - ssh
  - cron

log_files:
  - /var/log/syslog
  - /var/log/auth.log
  - /var/log/kern.log
EOF
echo -e "${GREEN}✓ Configuration created${NC}"

echo -e "${BLUE}🔧 Creating systemd service...${NC}"
cat > /etc/systemd/system/serverpulse-agent.service << EOF
[Unit]
Description=ServerPulse Monitoring Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/serverpulse_agent.py
ExecStop=/bin/sh -c '$INSTALL_DIR/venv/bin/python -c "
import sys, os, yaml, requests
from datetime import datetime
sys.path.insert(0, \"$INSTALL_DIR\")
try:
    with open(\"$INSTALL_DIR/config.yml\", \"r\") as f:
        config = yaml.safe_load(f)
    data = {
        \"timestamp\": datetime.now().isoformat(),
        \"server_id\": config.get(\"server_id\", \"unknown\"),
        \"status\": \"offline\",
        \"hostname\": os.uname().nodename
    }
    api_endpoint = config.get(\"api_endpoint\", \"\")
    server_id = config.get(\"server_id\", \"\")
    if api_endpoint and server_id:
        url = f\"{api_endpoint.rstrip(\"/\")}/servers/{server_id}/status\"
        headers = {\"Content-Type\": \"application/json\"}
        api_key = config.get(\"api_key\", \"\")
        if api_key:
            headers[\"Authorization\"] = f\"Bearer {api_key}\"
        requests.post(url, json=data, headers=headers, timeout=10)
        print(\"Offline status sent\")
except Exception as e:
    print(f\"Error sending offline status: {e}\")
"'

Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
TimeoutStopSec=30

Environment=PYTHONPATH=$INSTALL_DIR
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R root:root $INSTALL_DIR
chmod -R 755 $INSTALL_DIR
chmod +x $INSTALL_DIR/serverpulse_agent.py

# Enable service
systemctl daemon-reload
systemctl enable serverpulse-agent.service > /dev/null 2>&1
echo -e "${GREEN}✓ Service configured${NC}"

echo ""
echo -e "${GREEN}✅ Installation completed successfully!${NC}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Edit configuration: sudo nano $INSTALL_DIR/config.yml"
echo "2. Update 'api_endpoint' to your ServerPulse URL"
echo "3. Set 'server_id' to identify this server" 
echo "4. Add 'api_key' if authentication is required"
echo "5. Start the agent: sudo systemctl start serverpulse-agent"
echo ""
echo -e "${BLUE}💡 Useful commands:${NC}"
echo "  Check status: sudo systemctl status serverpulse-agent"
echo "  View logs:    sudo journalctl -u serverpulse-agent -f"
echo "  Restart:      sudo systemctl restart serverpulse-agent"
echo ""
echo -e "${GREEN}🎉 Ready to monitor your Ubuntu server!${NC}"
