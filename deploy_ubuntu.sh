#!/bin/bash

# Quick deployment script for Ubuntu VM
# Run this script to easily deploy the agent to your Ubuntu VM

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}ServerPulse Agent - Quick Ubuntu Deployment${NC}"
echo "=============================================="

# Check if we're on Windows (for development) or Linux (for deployment)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    echo "Detected Windows environment - preparing for VM deployment"
    
    echo -e "${YELLOW}Please provide your Ubuntu VM details:${NC}"
    read -p "VM IP address: " VM_IP
    read -p "VM username: " VM_USER
    read -p "ServerPulse URL (e.g., http://192.168.1.100:8080): " SERVERPULSE_URL
    read -s -p "ServerPulse auth token: " AUTH_TOKEN
    echo
    
    # Create temporary config with actual values
    sed "s|https://your-serverpulse-domain.com|$SERVERPULSE_URL|g; s|your-auth-token-here|$AUTH_TOKEN|g" config.yml.example > config.yml.temp
    
    echo -e "${YELLOW}Creating deployment package...${NC}"
    tar -czf serverpulse-agent-deploy.tar.gz .
    
    echo -e "${YELLOW}Transferring to Ubuntu VM...${NC}"
    scp serverpulse-agent-deploy.tar.gz $VM_USER@$VM_IP:/tmp/
    
    echo -e "${YELLOW}Running installation on VM...${NC}"
    ssh $VM_USER@$VM_IP << 'EOF'
        cd /tmp
        tar -xzf serverpulse-agent-deploy.tar.gz
        cd serverpulse-agent
        
        # Make scripts executable
        chmod +x install.sh
        chmod +x deploy_ubuntu.sh
        
        # Run installation
        sudo ./install.sh
        
        # Copy our pre-configured config
        if [ -f config.yml.temp ]; then
            sudo cp config.yml.temp /etc/serverpulse-agent/config.yml
            sudo chown serverpulse:serverpulse /etc/serverpulse-agent/config.yml
            sudo chmod 600 /etc/serverpulse-agent/config.yml
        fi
        
        # Start the agent
        sudo systemctl enable serverpulse-agent
        sudo systemctl start serverpulse-agent
        
        echo "Agent installation complete!"
        echo "Checking status..."
        sudo systemctl status serverpulse-agent --no-pager
EOF
    
    # Clean up
    rm -f config.yml.temp serverpulse-agent-deploy.tar.gz
    
    echo -e "${GREEN}Deployment complete!${NC}"
    echo ""
    echo "To check agent status on VM:"
    echo "  ssh $VM_USER@$VM_IP 'sudo systemctl status serverpulse-agent'"
    echo ""
    echo "To view logs:"
    echo "  ssh $VM_USER@$VM_IP 'sudo journalctl -u serverpulse-agent -f'"
    
else
    # Running on Linux - do local installation
    echo "Detected Linux environment - installing locally"
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        echo -e "${RED}This script requires sudo access${NC}"
        exit 1
    fi
    
    # Run installation
    if [ -f install.sh ]; then
        chmod +x install.sh
        sudo ./install.sh
        
        echo -e "${YELLOW}Installation complete!${NC}"
        echo "Please edit the configuration file:"
        echo "  sudo nano /etc/serverpulse-agent/config.yml"
        echo ""
        echo "Then start the agent:"
        echo "  sudo systemctl enable serverpulse-agent"
        echo "  sudo systemctl start serverpulse-agent"
    else
        echo -e "${RED}install.sh not found in current directory${NC}"
        exit 1
    fi
fi
