# ServerPulse Agent

A robust Linux monitoring agent for Ubuntu VMs that automatically collects system metrics, monitors services, detects crashes, and reports to a Laravel-based ServerPulse backend.

## Features

- 🖥️ **System Monitoring**: CPU, memory, disk, network metrics
- 🔧 **Service Monitoring**: Track status of critical services (Apache, Nginx, MySQL, etc.)
- 💥 **Crash Detection**: Monitor for kernel panics, OOM kills, and system crashes  
- 📋 **Log Monitoring**: Real-time monitoring of system logs for errors
- 🔄 **Auto-Recovery**: Automatically restarts on failure
- 🌐 **Online/Offline Status**: Reports server status including proper offline notification on shutdown
- ⚡ **Easy Installation**: One-click installation script for Ubuntu
- 🐍 **Python Environment Safe**: Handles Ubuntu's "externally managed Python" environment

## Quick Installation

### Single Command Installation

```bash
# Download and run the installer (works on any Linux distribution)
curl -sSL https://raw.githubusercontent.com/your-repo/serverpulse-agent/main/install_serverpulse_agent.sh | sudo bash
```

**OR download the script first:**

```bash
# Download the installer
wget https://raw.githubusercontent.com/your-repo/serverpulse-agent/main/install_serverpulse_agent.sh

# Make it executable and run
chmod +x install_serverpulse_agent.sh
sudo ./install_serverpulse_agent.sh
```

### Configure the Agent

```bash
# Edit the configuration
sudo nano /opt/serverpulse-agent/config.yml
```

**Required Changes:**
```yaml
# Change these to match your setup:
api_endpoint: "http://192.168.1.50:8000/api"  # Your ServerPulse URL
server_id: "my-ubuntu-server"                 # Unique name for this server
api_key: "your-api-key-here"                  # If authentication required
```

### Start Monitoring

```bash
# Start the agent
sudo systemctl start serverpulse-agent

# Check if it's running
sudo systemctl status serverpulse-agent

# View live logs
sudo journalctl -u serverpulse-agent -f
```

**That's it! Your server is now being monitored.** 🎉

## Testing the Installation

Run the built-in test script to verify everything is working:

```bash
# Test the agent (automatically created during installation)
sudo python3 /opt/serverpulse-agent/test_agent.py
```

This will check:
- ✅ Configuration is valid
- ✅ Metrics collection works
- ✅ API connection to ServerPulse

## Configuration Reference

The configuration file is located at `/opt/serverpulse-agent/config.yml`:

```yaml
# API Configuration
api_endpoint: "http://localhost:8000/api"     # ServerPulse URL
api_key: ""                                   # Authentication token (optional)
server_id: "ubuntu-server-1"                 # Unique server identifier
api_timeout: 30                               # API request timeout

# Collection Settings  
collection_interval: 30                      # Metrics collection interval (seconds)
heartbeat_interval: 60                       # Heartbeat interval (seconds)
log_level: "INFO"                            # Logging level

# Services to Monitor
services_to_monitor:
  - apache2
  - nginx  
  - mysql
  - postgresql
  - redis-server
  - docker
  - ssh
  - cron

# Log Files to Monitor
log_files:
  - /var/log/syslog
  - /var/log/auth.log
  - /var/log/kern.log
```

## Useful Commands

### Service Management
```bash
# Check status
sudo systemctl status serverpulse-agent

# Start/Stop/Restart
sudo systemctl start serverpulse-agent
sudo systemctl stop serverpulse-agent  
sudo systemctl restart serverpulse-agent

# Enable/Disable auto-start on boot
sudo systemctl enable serverpulse-agent
sudo systemctl disable serverpulse-agent
```

### Monitoring and Logs
```bash
# View real-time logs
sudo journalctl -u serverpulse-agent -f

# View recent logs
sudo journalctl -u serverpulse-agent --since "1 hour ago"

# Check agent log file
sudo tail -f /opt/serverpulse-agent/logs/agent.log
```

### Testing and Debugging
```bash
# Test the installation
sudo python3 /opt/serverpulse-agent/test_agent.py

# Test metrics collection manually
cd /opt/serverpulse-agent
sudo ./venv/bin/python -c "
from serverpulse_agent import ServerPulseAgent
import json
agent = ServerPulseAgent()
metrics = agent.collect_system_metrics()
print(json.dumps(metrics, indent=2))
"

# Test API connection
curl -X POST http://your-serverpulse-url/api/servers/test/status \
  -H "Content-Type: application/json" \
  -d '{"status": "test", "timestamp": "2024-01-01T00:00:00", "server_id": "test"}'
```

## Troubleshooting

### Common Issues and Solutions

**1. Installation Fails**
```bash
# Make sure you're running as root
sudo bash install_serverpulse_agent.sh

# Check if your Linux distribution is supported
cat /etc/os-release
```

**2. Service Won't Start**
```bash
# Check the service status
sudo systemctl status serverpulse-agent

# Check logs for errors
sudo journalctl -u serverpulse-agent -l

# Common fixes:
sudo chmod +x /opt/serverpulse-agent/serverpulse_agent.py
sudo chown -R root:root /opt/serverpulse-agent
```

**3. Connection to ServerPulse Fails**
```bash
# Test network connectivity
ping your-serverpulse-server-ip

# Test if ServerPulse is running
curl http://your-serverpulse-url/api/health

# Check firewall (Ubuntu)
sudo ufw status
sudo ufw allow from your-serverpulse-ip
```

**4. Agent Stops Running**
```bash
# Check system resources
free -h
df -h

# Restart the agent
sudo systemctl restart serverpulse-agent

# Check for errors
sudo journalctl -u serverpulse-agent --since "10 minutes ago"
```

**5. Metrics Not Appearing in Dashboard**
```bash
# Verify configuration
sudo cat /opt/serverpulse-agent/config.yml

# Test the agent manually
sudo python3 /opt/serverpulse-agent/test_agent.py

# Check ServerPulse logs on your Laravel server
```

### Getting Help

If you're still having issues:

1. **Check the logs**: `sudo journalctl -u serverpulse-agent -f`
2. **Run the test script**: `sudo python3 /opt/serverpulse-agent/test_agent.py`
3. **Verify your configuration**: `sudo nano /opt/serverpulse-agent/config.yml`
4. **Check ServerPulse is accessible**: `ping your-serverpulse-server`

## What Gets Installed

The single installation script creates:

- **Main Agent**: `/opt/serverpulse-agent/serverpulse_agent.py`
- **Configuration**: `/opt/serverpulse-agent/config.yml`
- **Virtual Environment**: `/opt/serverpulse-agent/venv/`
- **Logs**: `/opt/serverpulse-agent/logs/agent.log`
- **Test Script**: `/opt/serverpulse-agent/test_agent.py`
- **Service**: `/etc/systemd/system/serverpulse-agent.service`

## Supported Linux Distributions

The installer automatically detects and works with:
- ✅ Ubuntu (all versions)
- ✅ Debian (all versions)  
- ✅ CentOS / RHEL / Rocky Linux / AlmaLinux
- ✅ Fedora
- ✅ openSUSE / SLES
- ✅ Arch Linux / Manjaro
- ✅ Most other Linux distributions

## Features in Detail

### System Metrics
- CPU usage and core count
- Memory and swap usage
- Disk usage for all partitions
- Network I/O statistics
- System load averages
- Uptime information

### Service Monitoring
- Monitors critical services like Apache, Nginx, MySQL
- Reports service status (running, stopped, failed)
- Tracks service restarts and failures

### Crash Detection
- Monitors for kernel panics
- Detects Out of Memory (OOM) kills
- Checks for crash dump files
- Scans system logs for critical errors

### Automatic Startup/Shutdown
- Starts automatically on boot
- Sends "offline" status when shutting down
- Auto-restarts if the agent crashes
- Proper signal handling for clean shutdowns

## Laravel Backend

For complete Laravel integration instructions, see [LARAVEL_INTEGRATION.md](LARAVEL_INTEGRATION.md).

Quick Laravel setup:
1. Add API routes for agent endpoints
2. Create Server and Metric models  
3. Handle incoming agent data
4. Display metrics in dashboard

## License

MIT License - see LICENSE file for details.
