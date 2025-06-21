#!/bin/bash

# ServerPulse Agent - One-Click Installation Script for Ubuntu
# This script handles everything: dependencies, installation, configuration, and startup

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

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ServerPulse Agent - One-Click Install ${NC}"
echo -e "${GREEN}========================================${NC}"
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
    echo "----------------------------------------"
}

# Step 1: Update system and install dependencies
print_step "Step 1: Installing system dependencies..."
apt-get update -qq
apt-get install -y python3 python3-pip python3-venv systemd curl wget > /dev/null 2>&1
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Step 2: Create user and directories
print_step "Step 2: Creating user and directories..."
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

# Step 3: Copy agent files
print_step "Step 3: Installing agent files..."
cp -r $SCRIPT_DIR/* $INSTALL_DIR/ 2>/dev/null || true
echo -e "${GREEN}✓ Agent files copied to $INSTALL_DIR${NC}"

# Step 4: Create virtual environment and install Python packages
print_step "Step 4: Setting up Python environment..."
cd $INSTALL_DIR
python3 -m venv venv
source venv/bin/activate

# Update requirements.txt to fix common issues
cat > requirements.txt << 'EOF'
psutil>=5.9.0
requests>=2.28.0
pyyaml>=6.0
schedule>=1.2.0
websocket-client>=1.4.0
setproctitle>=1.3.0
systemd-python; sys_platform == "linux"
EOF

# Install packages
venv/bin/pip install --upgrade pip > /dev/null 2>&1
venv/bin/pip install -r requirements.txt > /dev/null 2>&1
echo -e "${GREEN}✓ Python packages installed${NC}"

# Step 5: Create proper systemd service
print_step "Step 5: Creating systemd service..."
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
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/serverpulse_agent.py $CONFIG_DIR/config.yml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
TimeoutStopSec=20

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

# Step 6: Set permissions
print_step "Step 6: Setting permissions..."
chown -R $AGENT_USER:$AGENT_USER $INSTALL_DIR
chown -R $AGENT_USER:$AGENT_USER $CONFIG_DIR
chmod +x $INSTALL_DIR/serverpulse_agent.py
chmod +x $INSTALL_DIR/agent_cli.py
echo -e "${GREEN}✓ Permissions set${NC}"

# Step 7: Create configuration file
print_step "Step 7: Creating configuration..."
if [ ! -f $CONFIG_DIR/config.yml ]; then
    cat > $CONFIG_DIR/config.yml << EOF
server:
  # CHANGE THIS: Your Laravel ServerPulse URL
  endpoint: "http://YOUR_LARAVEL_SERVER_IP:PORT/api/v1"
  
  # CHANGE THIS: Your authentication token from Laravel
  auth_token: "your-auth-token-here"
  
  # Unique agent identifier
  agent_id: "$(hostname)-$(date +%s)"

collection:
  interval: 30  # seconds
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
    - postgresql
    - docker
    - cron
  log_paths:
    - /var/log/syslog
    - /var/log/kern.log
    - /var/log/auth.log
  custom_logs:
    - path: /var/log/auth.log
      parser: auth
      patterns:
        - "Failed password.*"
        - "Invalid user.*"

alerts:
  cpu_threshold: 80
  memory_threshold: 85
  disk_threshold: 90
  load_threshold: 5.0

logging:
  level: INFO
  file: /var/log/serverpulse-agent.log
  max_size: 10MB
  backup_count: 5
EOF
    
    chown $AGENT_USER:$AGENT_USER $CONFIG_DIR/config.yml
    chmod 600 $CONFIG_DIR/config.yml
    echo -e "${GREEN}✓ Configuration file created${NC}"
else
    echo -e "${GREEN}✓ Configuration file already exists${NC}"
fi

# Step 8: Enable and start service
print_step "Step 8: Starting agent service..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME > /dev/null 2>&1
echo -e "${GREEN}✓ Service enabled for auto-start${NC}"

# Get user input for configuration
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}         Configuration Setup            ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

read -p "Enter your Laravel ServerPulse URL (e.g., http://192.168.1.100:8000): " SERVERPULSE_URL
read -p "Enter your authentication token: " AUTH_TOKEN

# Update configuration with user input
if [ -n "$SERVERPULSE_URL" ] && [ -n "$AUTH_TOKEN" ]; then
    sed -i "s|http://YOUR_LARAVEL_SERVER_IP:PORT/api/v1|$SERVERPULSE_URL/api/v1|g" $CONFIG_DIR/config.yml
    sed -i "s|your-auth-token-here|$AUTH_TOKEN|g" $CONFIG_DIR/config.yml
    echo -e "${GREEN}✓ Configuration updated${NC}"
    
    # Start the service
    systemctl start $SERVICE_NAME
    sleep 3
    
    # Check status
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo -e "${GREEN}✓ Agent started successfully!${NC}"
    else
        echo -e "${RED}⚠ Agent failed to start. Checking logs...${NC}"
        systemctl status $SERVICE_NAME --no-pager
    fi
else
    echo -e "${YELLOW}⚠ Skipping auto-start. Please configure manually:${NC}"
    echo "  sudo nano $CONFIG_DIR/config.yml"
    echo "  sudo systemctl start $SERVICE_NAME"
fi

# Final instructions
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}       Installation Complete!          ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Configuration file:${NC} $CONFIG_DIR/config.yml"
echo -e "${BLUE}Log file:${NC} /var/log/serverpulse-agent.log"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  Check status:    sudo systemctl status $SERVICE_NAME"
echo "  View logs:       sudo journalctl -u $SERVICE_NAME -f"
echo "  Test agent:      sudo -u $AGENT_USER $INSTALL_DIR/venv/bin/python $INSTALL_DIR/agent_cli.py collect-metrics"
echo "  Test connection: sudo -u $AGENT_USER $INSTALL_DIR/venv/bin/python $INSTALL_DIR/agent_cli.py test-connection"
echo ""
echo -e "${GREEN}Your ServerPulse agent is now monitoring this server!${NC}"
