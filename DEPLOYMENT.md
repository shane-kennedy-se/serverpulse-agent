# ServerPulse Agent - Deployment Guide

## Quick Deploy to Any Linux VM

### Option 1: One-Line Install (Recommended)

```bash
# Download and install in one command
curl -sSL https://raw.githubusercontent.com/your-repo/serverpulse-agent/main/install_serverpulse_agent.sh | sudo bash
```

### Option 2: Download First, Then Install

```bash
# Download the installer
wget https://raw.githubusercontent.com/your-repo/serverpulse-agent/main/install_serverpulse_agent.sh

# Make executable and run
chmod +x install_serverpulse_agent.sh
sudo ./install_serverpulse_agent.sh
```

## After Installation

### 1. Configure the Agent

```bash
sudo nano /opt/serverpulse-agent/config.yml
```

**Update these lines:**
```yaml
api_endpoint: "http://192.168.1.50:8000/api"  # Your ServerPulse URL
server_id: "my-production-server"             # Unique name for this server
api_key: "your-api-key-here"                  # Optional API key
```

### 2. Start the Agent

```bash
sudo systemctl start serverpulse-agent
```

### 3. Verify Installation

```bash
# Test everything works
sudo python3 /opt/serverpulse-agent/test_agent.py

# Check service status
sudo systemctl status serverpulse-agent

# View live logs
sudo journalctl -u serverpulse-agent -f
```

## What It Does

✅ **Automatically detects your Linux distribution**  
✅ **Installs Python and dependencies properly**  
✅ **Creates a complete monitoring agent**  
✅ **Sets up automatic startup on boot**  
✅ **Configures proper shutdown with offline status**  
✅ **Includes built-in testing tools**  

## Supported Systems

- Ubuntu (all versions)
- Debian (all versions)
- CentOS / RHEL / Rocky Linux
- Fedora
- openSUSE / SLES
- Arch Linux / Manjaro
- Most other Linux distributions

## Monitoring Features

- **System Metrics**: CPU, memory, disk, network usage
- **Service Status**: Monitors common services (Apache, Nginx, MySQL, etc.)
- **Real-time Reporting**: Sends data every 30 seconds
- **Heartbeat**: Keeps connection alive
- **Offline Detection**: Reports when server goes down
- **Auto-Recovery**: Restarts automatically if it crashes

## Example Usage

```bash
# On your Ubuntu VM
curl -sSL https://raw.githubusercontent.com/your-repo/serverpulse-agent/main/install_serverpulse_agent.sh | sudo bash

# Configure
sudo nano /opt/serverpulse-agent/config.yml
# Update api_endpoint to: http://192.168.1.100:8000/api
# Update server_id to: ubuntu-web-server

# Start monitoring
sudo systemctl start serverpulse-agent

# Test
sudo python3 /opt/serverpulse-agent/test_agent.py
```

## Troubleshooting

**Installation fails:**
```bash
# Check you have sudo access
sudo whoami

# Check internet connectivity
ping google.com

# Check Linux distribution
cat /etc/os-release
```

**Agent won't start:**
```bash
# Check logs
sudo journalctl -u serverpulse-agent -l

# Check configuration
sudo cat /opt/serverpulse-agent/config.yml

# Test manually
cd /opt/serverpulse-agent
sudo ./venv/bin/python serverpulse_agent.py
```

**Can't connect to ServerPulse:**
```bash
# Test network
ping your-serverpulse-server-ip

# Test API endpoint
curl http://your-serverpulse-server:8000/api/health

# Check firewall
sudo ufw status
```

## For Developers

The installer creates a complete, self-contained agent with:
- Virtual Python environment to avoid conflicts
- Comprehensive system metrics collection
- Proper signal handling for graceful shutdown
- Systemd service for auto-start and management
- Built-in testing and debugging tools

The agent is designed to be reliable, lightweight, and work on any modern Linux system.
