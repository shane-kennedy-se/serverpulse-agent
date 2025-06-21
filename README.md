# ServerPulse Linux Agent

A comprehensive Linux monitoring agent that collects system metrics, monitors services, detects crashes, and sends real-time data to your ServerPulse server management application.

## Features

- **Real-time System Monitoring**: CPU, memory, disk, network, and uptime metrics
- **Service Management**: Monitor systemd services for failures and status changes
- **Crash Detection**: Automatically detect system crashes, kernel panics, and critical errors
- **Log Monitoring**: Monitor custom log files for errors and events
- **Alert System**: Intelligent alerting with configurable thresholds
- **Secure Communication**: TLS-encrypted communication with ServerPulse
- **Easy Installation**: Automated installation script for major Linux distributions

## Quick Installation

1. **Download the agent:**
   ```bash
   wget https://github.com/yourusername/serverpulse-agent/archive/main.zip
   unzip main.zip
   cd serverpulse-agent-main
   ```

2. **Run the installation script:**
   ```bash
   sudo chmod +x install.sh
   sudo ./install.sh
   ```

3. **Configure the agent:**
   ```bash
   sudo nano /etc/serverpulse-agent/config.yml
   ```
   
   Update the following settings:
   - `server.endpoint`: Your ServerPulse server URL
   - `server.auth_token`: Authentication token from ServerPulse
   - `server.agent_id`: Unique identifier for this agent

4. **Start the agent:**
   ```bash
   sudo systemctl enable serverpulse-agent
   sudo systemctl start serverpulse-agent
   ```

5. **Check status:**
   ```bash
   sudo systemctl status serverpulse-agent
   ```

## Manual Installation

### Prerequisites

- Python 3.6 or higher
- pip3
- systemd (for service management)

### Installation Steps

1. **Install Python dependencies:**
   ```bash
   pip3 install -r requirements.txt
   ```

2. **Create configuration directory:**
   ```bash
   sudo mkdir -p /etc/serverpulse-agent
   sudo cp config.yml.example /etc/serverpulse-agent/config.yml
   ```

3. **Edit configuration:**
   ```bash
   sudo nano /etc/serverpulse-agent/config.yml
   ```

4. **Create systemd service:**
   ```bash
   sudo cp serverpulse-agent.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

5. **Start the agent:**
   ```bash
   sudo systemctl enable serverpulse-agent
   sudo systemctl start serverpulse-agent
   ```

## Configuration

The agent is configured through `/etc/serverpulse-agent/config.yml`. Here are the main configuration sections:

### Server Configuration
```yaml
server:
  endpoint: "https://your-serverpulse-domain.com"
  auth_token: "your-auth-token-here"
  agent_id: "unique-agent-id"
```

### Collection Settings
```yaml
collection:
  interval: 30  # Data collection interval in seconds
  metrics:
    - system_stats
    - disk_usage
    - network_stats
    - process_list
```

### Service Monitoring
```yaml
monitoring:
  services:
    - ssh
    - nginx
    - mysql
    - docker
```

### Alert Thresholds
```yaml
alerts:
  cpu_threshold: 80      # CPU usage percentage
  memory_threshold: 85   # Memory usage percentage
  disk_threshold: 90     # Disk usage percentage
  load_threshold: 5.0    # System load average
```

## Collected Metrics

### System Metrics
- CPU usage (overall and per-core)
- Memory usage (RAM and swap)
- Disk usage and I/O statistics
- Network interface statistics
- System uptime and load average
- Top processes by CPU and memory usage

### Service Monitoring
- Service status (active, failed, stopped)
- Service start times
- Service restart counts
- Failed service detection

### Crash Detection
- Kernel panics and oops
- Segmentation faults
- Out of memory events
- Hardware errors
- Filesystem errors
- Service crashes

### Log Monitoring
- Authentication failures
- Web server errors
- Database errors
- Custom log patterns

## API Endpoints

The agent communicates with ServerPulse through these API endpoints:

- `POST /api/v1/agents/register` - Agent registration
- `POST /api/v1/agents/{id}/metrics` - Send metrics data
- `POST /api/v1/agents/{id}/heartbeat` - Send heartbeat
- `POST /api/v1/agents/{id}/alerts` - Send alerts
- `GET /api/v1/agents/{id}/commands` - Get pending commands

## Logging

Logs are written to `/var/log/serverpulse-agent.log` and can also be viewed using:

```bash
# View service logs
sudo journalctl -u serverpulse-agent -f

# View log file
sudo tail -f /var/log/serverpulse-agent.log
```

Log levels can be configured in the config file:
- DEBUG: Detailed debugging information
- INFO: General operational messages
- WARNING: Warning messages
- ERROR: Error messages
- CRITICAL: Critical error messages

## Troubleshooting

### Check Agent Status
```bash
sudo systemctl status serverpulse-agent
```

### View Recent Logs
```bash
sudo journalctl -u serverpulse-agent --since "1 hour ago"
```

### Test Configuration
```bash
sudo -u serverpulse python3 /opt/serverpulse-agent/serverpulse_agent.py /etc/serverpulse-agent/config.yml
```

### Common Issues

1. **Connection Error**: Check network connectivity and server endpoint
2. **Authentication Failed**: Verify auth_token in configuration
3. **Permission Denied**: Ensure agent user has proper permissions
4. **Service Won't Start**: Check configuration file syntax

### Debug Mode
To run the agent in debug mode:
```bash
sudo systemctl stop serverpulse-agent
sudo -u serverpulse python3 /opt/serverpulse-agent/serverpulse_agent.py /etc/serverpulse-agent/config.yml
```

## Security

- All communication is encrypted using TLS
- Agent runs with minimal privileges
- Configuration files have restricted permissions
- Authentication tokens are stored securely

## Supported Linux Distributions

- Ubuntu 18.04+
- Debian 9+
- CentOS/RHEL 7+
- Fedora 30+
- Amazon Linux 2
- SUSE Linux Enterprise 12+

## Requirements

- Python 3.6+
- Root access for installation
- Network connectivity to ServerPulse server
- Systemd for service management

## Development

To contribute to the agent development:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/serverpulse-agent.git
   cd serverpulse-agent
   ```

2. **Install development dependencies:**
   ```bash
   pip3 install -r requirements.txt
   ```

3. **Run tests:**
   ```bash
   python3 -m pytest tests/
   ```

4. **Submit pull requests** with your improvements

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support, please contact:
- Email: support@serverpulse.com
- Documentation: https://docs.serverpulse.com
- GitHub Issues: https://github.com/yourusername/serverpulse-agent/issues
