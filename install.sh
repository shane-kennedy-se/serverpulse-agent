#!/bin/bash

# ServerPulse Agent Installation Script
# This script installs the ServerPulse monitoring agent on Linux systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AGENT_USER="serverpulse"
AGENT_GROUP="serverpulse"
INSTALL_DIR="/opt/serverpulse-agent"
CONFIG_DIR="/etc/serverpulse-agent"
LOG_DIR="/var/log"
SERVICE_NAME="serverpulse-agent"

echo -e "${GREEN}ServerPulse Agent Installation${NC}"
echo "================================="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Detect Linux distribution
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        echo -e "${RED}Cannot detect Linux distribution${NC}"
        exit 1
    fi
    
    echo "Detected OS: $OS"
}

# Install Python and dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing dependencies...${NC}"
    
    case $DISTRO in
        ubuntu|debian)
            apt-get update
            apt-get install -y python3 python3-pip python3-venv systemd curl wget
            # Ensure pip is up to date
            python3 -m pip install --upgrade pip
            ;;
        centos|rhel|fedora)
            if command -v dnf &> /dev/null; then
                dnf install -y python3 python3-pip systemd curl wget
            else
                yum install -y python3 python3-pip systemd curl wget
            fi
            # Ensure pip is up to date
            python3 -m pip install --upgrade pip
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO${NC}"
            echo "Supported distributions: Ubuntu, Debian, CentOS, RHEL, Fedora"
            exit 1
            ;;
    esac
}

# Create user and directories
create_user_and_dirs() {
    echo -e "${YELLOW}Creating user and directories...${NC}"
    
    # Create user if it doesn't exist
    if ! id "$AGENT_USER" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false $AGENT_USER
        echo "Created user: $AGENT_USER"
    fi
    
    # Create directories
    mkdir -p $INSTALL_DIR
    mkdir -p $CONFIG_DIR
    mkdir -p $LOG_DIR
    
    # Set ownership
    chown -R $AGENT_USER:$AGENT_GROUP $INSTALL_DIR
    chown -R $AGENT_USER:$AGENT_GROUP $CONFIG_DIR
}

# Install agent files
install_agent() {
    echo -e "${YELLOW}Installing agent files...${NC}"
    
    # Copy agent files
    cp -r ./* $INSTALL_DIR/
    
    # Create virtual environment
    python3 -m venv $INSTALL_DIR/venv
    
    # Install Python dependencies
    $INSTALL_DIR/venv/bin/pip install --upgrade pip
    $INSTALL_DIR/venv/bin/pip install -r $INSTALL_DIR/requirements.txt
    
    # Make main script executable
    chmod +x $INSTALL_DIR/serverpulse_agent.py
    
    # Set ownership
    chown -R $AGENT_USER:$AGENT_GROUP $INSTALL_DIR
}

# Create systemd service
create_systemd_service() {
    echo -e "${YELLOW}Creating systemd service...${NC}"
    
    cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=ServerPulse Monitoring Agent
After=network.target
Wants=network.target

[Service]
Type=simple
User=$AGENT_USER
Group=$AGENT_GROUP
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/serverpulse_agent.py $CONFIG_DIR/config.yml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$LOG_DIR $CONFIG_DIR

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload
}

# Create default configuration
create_config() {
    echo -e "${YELLOW}Creating configuration file...${NC}"
    
    if [ ! -f $CONFIG_DIR/config.yml ]; then
        cat > $CONFIG_DIR/config.yml << EOF
server:
  endpoint: "https://your-serverpulse-domain.com"
  auth_token: "your-auth-token-here"
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
    - docker
  log_paths:
    - /var/log/syslog
    - /var/log/kern.log
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
        
        chown $AGENT_USER:$AGENT_GROUP $CONFIG_DIR/config.yml
        chmod 600 $CONFIG_DIR/config.yml
        
        echo -e "${YELLOW}Configuration file created at $CONFIG_DIR/config.yml${NC}"
        echo -e "${YELLOW}Please edit this file with your ServerPulse details before starting the agent${NC}"
    else
        echo "Configuration file already exists at $CONFIG_DIR/config.yml"
    fi
}

# Main installation function
main() {
    detect_os
    install_dependencies
    create_user_and_dirs
    install_agent
    create_systemd_service
    create_config
    
    echo ""
    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Edit the configuration file: $CONFIG_DIR/config.yml"
    echo "2. Add your ServerPulse endpoint and authentication token"
    echo "3. Enable the service: systemctl enable $SERVICE_NAME"
    echo "4. Start the service: systemctl start $SERVICE_NAME"
    echo "5. Check status: systemctl status $SERVICE_NAME"
    echo ""
    echo "Logs can be found at: /var/log/serverpulse-agent.log"
    echo "And in systemd journal: journalctl -u $SERVICE_NAME -f"
}

# Run installation
main
