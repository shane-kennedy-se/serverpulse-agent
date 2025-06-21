# ServerPulse Agent - One-Click Installation

## 🚀 Quick Start for Ubuntu VM

### Step 1: Clone and Install
```bash
git clone <your-repo-url>
cd serverpulse-agent
sudo ./easy_install.sh
```

That's it! The script will:
- ✅ Install all dependencies automatically
- ✅ Set up the agent as a system service
- ✅ Copy files to `/opt/serverpulse-agent`
- ✅ Ask for your Laravel URL and token
- ✅ Start monitoring immediately

### Step 2: Verify Installation
```bash
# Check if agent is running
sudo systemctl status serverpulse-agent

# View live logs
sudo journalctl -u serverpulse-agent -f

# Test metrics collection
sudo -u serverpulse /opt/serverpulse-agent/venv/bin/python /opt/serverpulse-agent/agent_cli.py collect-metrics
```

---

## 🔧 Laravel Backend Setup

### Required API Endpoints
Your Laravel app needs these routes in `routes/api.php`:

```php
Route::prefix('v1/agents')->group(function () {
    Route::post('register', [AgentController::class, 'register']);
    Route::post('{agent_id}/metrics', [AgentController::class, 'receiveMetrics']);
    Route::post('{agent_id}/heartbeat', [AgentController::class, 'heartbeat']);
    Route::post('{agent_id}/alerts', [AgentController::class, 'receiveAlert']);
});
```

### Test Laravel Connection
Before installing the agent, test your Laravel backend:
```bash
python3 test_laravel_connection.py
```

---

## 📊 What Gets Monitored

- **System Metrics**: CPU, Memory, Disk, Network usage
- **Services**: SSH, Nginx, MySQL, Docker, etc.
- **Crashes**: Kernel panics, OOM events, segfaults
- **Logs**: Authentication failures, web server errors
- **Alerts**: Automatic threshold-based alerts

---

## 🔧 Configuration

Edit `/etc/serverpulse-agent/config.yml` after installation:

```yaml
server:
  endpoint: "http://your-laravel-server:80/api/v1"
  auth_token: "your-laravel-token"
  agent_id: "ubuntu-vm-01"
```

Restart after changes:
```bash
sudo systemctl restart serverpulse-agent
```

---

## 📁 File Locations

- **Agent Code**: `/opt/serverpulse-agent/`
- **Configuration**: `/etc/serverpulse-agent/config.yml`
- **Logs**: `/var/log/serverpulse-agent.log`
- **Service**: `/etc/systemd/system/serverpulse-agent.service`

---

## 🎯 Benefits

1. **Real-time Monitoring**: Live server metrics in your Laravel dashboard
2. **Proactive Alerts**: Get notified before problems become critical
3. **Service Monitoring**: Automatic detection of failed services
4. **Historical Data**: Track performance trends over time
5. **Easy Management**: Simple web interface for all your servers

---

## 🚨 Troubleshooting

### Agent won't start?
```bash
# Check logs
sudo journalctl -u serverpulse-agent -e

# Check configuration
sudo nano /etc/serverpulse-agent/config.yml

# Test manually
sudo -u serverpulse /opt/serverpulse-agent/venv/bin/python /opt/serverpulse-agent/serverpulse_agent.py
```

### Can't connect to Laravel?
```bash
# Test connection
python3 test_laravel_connection.py

# Check firewall
sudo ufw status

# Verify Laravel is running
curl http://your-laravel-url/api/v1/agents/register
```

---

Your agent will now automatically monitor your Ubuntu VM and send all data to your Laravel ServerPulse dashboard! 🎉
