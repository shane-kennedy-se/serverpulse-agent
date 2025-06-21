# ServerPulse Agent - Ubuntu VM Deployment Guide

## Prerequisites

1. **Ubuntu VM** with internet access
2. **Root/sudo access** on the VM
3. **ServerPulse server** running and accessible
4. **Network connectivity** between VM and ServerPulse server

## Step 1: Transfer Agent Files to Ubuntu VM

### Option A: Using SCP (if you have SSH access)
```bash
# On your Windows machine, compress the agent files
tar -czf serverpulse-agent.tar.gz -C d:\Programming\ serverpulse-agent

# Transfer to Ubuntu VM
scp serverpulse-agent.tar.gz user@your-vm-ip:/tmp/

# On Ubuntu VM, extract
cd /tmp
tar -xzf serverpulse-agent.tar.gz
```

### Option B: Using Git (recommended)
```bash
# On Ubuntu VM
sudo apt update
sudo apt install -y git
git clone https://github.com/yourusername/serverpulse-agent.git
cd serverpulse-agent
```

### Option C: Direct download (if you host the files)
```bash
# On Ubuntu VM
wget https://your-server.com/serverpulse-agent.tar.gz
tar -xzf serverpulse-agent.tar.gz
cd serverpulse-agent
```

## Step 2: Run the Installation

```bash
# Make installation script executable
chmod +x install.sh

# Run installation (requires sudo)
sudo ./install.sh
```

## Step 3: Configure the Agent

### Edit the configuration file:
```bash
sudo nano /etc/serverpulse-agent/config.yml
```

### Update these key settings:
```yaml
server:
  # Replace with your actual ServerPulse URL
  endpoint: "http://your-serverpulse-server:port"
  # or if using HTTPS: "https://your-serverpulse-domain.com"
  
  # Get this token from your ServerPulse admin panel
  auth_token: "your-actual-auth-token"
  
  # Unique ID for this VM (auto-generated is fine)
  agent_id: "ubuntu-vm-01"
```

## Step 4: Start the Agent

```bash
# Enable auto-start on boot
sudo systemctl enable serverpulse-agent

# Start the agent now
sudo systemctl start serverpulse-agent

# Check status
sudo systemctl status serverpulse-agent
```

## Step 5: Verify Operation

### Check agent logs:
```bash
# View recent logs
sudo journalctl -u serverpulse-agent -f

# Or check log file
sudo tail -f /var/log/serverpulse-agent.log
```

### Test agent functionality:
```bash
# Test configuration
sudo -u serverpulse python3 /opt/serverpulse-agent/agent_cli.py validate-config

# Test metrics collection
sudo -u serverpulse python3 /opt/serverpulse-agent/agent_cli.py collect-metrics

# Test connection to ServerPulse
sudo -u serverpulse python3 /opt/serverpulse-agent/agent_cli.py test-connection
```

## Troubleshooting

### Check agent status:
```bash
sudo systemctl status serverpulse-agent
```

### View detailed logs:
```bash
sudo journalctl -u serverpulse-agent --since "10 minutes ago"
```

### Test manually:
```bash
# Stop service
sudo systemctl stop serverpulse-agent

# Run manually for debugging
sudo -u serverpulse python3 /opt/serverpulse-agent/serverpulse_agent.py /etc/serverpulse-agent/config.yml
```

### Common issues:

1. **Connection refused**: Check ServerPulse URL and firewall
2. **Permission denied**: Ensure agent user has proper permissions
3. **Module not found**: Reinstall dependencies with pip3

## ServerPulse Server Requirements

Your ServerPulse server needs these API endpoints to receive agent data:

### 1. Agent Registration
```
POST /api/v1/agents/register
Content-Type: application/json
Authorization: Bearer {auth_token}

{
  "agent_id": "ubuntu-vm-01",
  "hostname": "vm-hostname",
  "system": "Linux",
  "version": "Ubuntu 22.04"
}
```

### 2. Metrics Endpoint
```
POST /api/v1/agents/{agent_id}/metrics
Content-Type: application/json
Authorization: Bearer {auth_token}

{
  "agent_id": "ubuntu-vm-01",
  "timestamp": "2025-06-21T19:00:00Z",
  "metrics": {
    "cpu": {"usage_percent": 25.5},
    "memory": {"percent": 78.2},
    "disk": {...},
    "network": {...}
  }
}
```

### 3. Heartbeat Endpoint
```
POST /api/v1/agents/{agent_id}/heartbeat
Content-Type: application/json
Authorization: Bearer {auth_token}

{
  "agent_id": "ubuntu-vm-01",
  "timestamp": "2025-06-21T19:00:00Z",
  "status": "online"
}
```

### 4. Alerts Endpoint
```
POST /api/v1/agents/{agent_id}/alerts
Content-Type: application/json
Authorization: Bearer {auth_token}

{
  "agent_id": "ubuntu-vm-01",
  "timestamp": "2025-06-21T19:00:00Z",
  "alert": {
    "type": "high_cpu",
    "severity": "high",
    "message": "CPU usage is 95%"
  }
}
```

## Network Configuration

### If ServerPulse is on the same network:
```yaml
server:
  endpoint: "http://192.168.1.100:8080"  # Local IP
```

### If using Docker for ServerPulse:
```yaml
server:
  endpoint: "http://host.docker.internal:8080"  # From container
```

### If ServerPulse is remote:
```yaml
server:
  endpoint: "https://serverpulse.yourdomain.com"
```

## Security Notes

- Agent runs with minimal privileges (`serverpulse` user)
- All communication should use HTTPS in production
- Store auth tokens securely
- Configure firewall rules as needed
