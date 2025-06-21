#!/bin/bash

# Simple setup script for Ubuntu
# Use this if you've manually copied the files to your Ubuntu VM

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}ServerPulse Agent Setup for Ubuntu${NC}"
echo "===================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Don't run this script as root. Use sudo when needed.${NC}"
   exit 1
fi

# Check if we're in the right directory
if [ ! -f "serverpulse_agent.py" ]; then
    echo -e "${RED}Error: serverpulse_agent.py not found. Are you in the agent directory?${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Installing system dependencies...${NC}"
sudo apt update
sudo apt install -y python3 python3-pip python3-venv systemd

echo -e "${YELLOW}Step 2: Installing Python dependencies...${NC}"
pip3 install -r requirements.txt

echo -e "${YELLOW}Step 3: Running installation script...${NC}"
chmod +x install.sh
sudo ./install.sh

echo -e "${YELLOW}Step 4: Configuration setup...${NC}"
echo "Please configure the agent for your ServerPulse server:"
echo ""
echo "1. Edit the configuration file:"
echo "   sudo nano /etc/serverpulse-agent/config.yml"
echo ""
echo "2. Update these settings:"
echo "   - server.endpoint: Your ServerPulse URL"
echo "   - server.auth_token: Your authentication token"
echo "   - server.agent_id: Unique ID for this server"
echo ""
echo "3. Start the agent:"
echo "   sudo systemctl enable serverpulse-agent"
echo "   sudo systemctl start serverpulse-agent"
echo ""
echo "4. Check status:"
echo "   sudo systemctl status serverpulse-agent"
echo ""

# Prompt for immediate configuration
read -p "Would you like to configure the agent now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    read -p "ServerPulse URL (e.g., http://192.168.1.100:8080): " SERVERPULSE_URL
    read -p "Auth token: " AUTH_TOKEN
    read -p "Agent ID (leave empty for auto-generated): " AGENT_ID
    
    if [ -z "$AGENT_ID" ]; then
        AGENT_ID="$(hostname)-$(date +%s)"
    fi
    
    echo -e "${YELLOW}Updating configuration...${NC}"
    
    # Create updated config
    sudo cp /etc/serverpulse-agent/config.yml /etc/serverpulse-agent/config.yml.backup
    
    sudo sed -i "s|https://your-serverpulse-domain.com|$SERVERPULSE_URL|g" /etc/serverpulse-agent/config.yml
    sudo sed -i "s|your-auth-token-here|$AUTH_TOKEN|g" /etc/serverpulse-agent/config.yml
    sudo sed -i "s|auto-generated-id|$AGENT_ID|g" /etc/serverpulse-agent/config.yml
    
    echo -e "${YELLOW}Starting agent...${NC}"
    sudo systemctl enable serverpulse-agent
    sudo systemctl start serverpulse-agent
    
    echo -e "${GREEN}Agent started! Checking status...${NC}"
    sleep 2
    sudo systemctl status serverpulse-agent --no-pager
    
    echo ""
    echo -e "${GREEN}Setup complete!${NC}"
    echo ""
    echo "Useful commands:"
    echo "  View logs: sudo journalctl -u serverpulse-agent -f"
    echo "  Test connection: sudo -u serverpulse python3 /opt/serverpulse-agent/agent_cli.py test-connection"
    echo "  Test metrics: sudo -u serverpulse python3 /opt/serverpulse-agent/agent_cli.py collect-metrics"
fi

echo ""
echo -e "${GREEN}Setup script completed!${NC}"
