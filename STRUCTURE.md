# ServerPulse Agent - File Structure

This repository contains a streamlined ServerPulse monitoring agent with minimal files for maximum simplicity.

## Files Overview

### 🚀 Core Installation
- **`install_serverpulse_agent.sh`** - Single installation script that contains everything
  - Detects Linux distribution automatically
  - Installs Python dependencies safely
  - Creates complete monitoring agent
  - Sets up systemd service for auto-start
  - Includes built-in test functionality

### 📖 Documentation  
- **`README.md`** - Complete installation and usage guide
- **`DEPLOYMENT.md`** - Quick deployment instructions
- **`LARAVEL_INTEGRATION.md`** - Laravel backend integration guide

### 🔧 Utilities
- **`transfer_to_vm.bat`** - Windows script to transfer files to Linux VM

## What the Installer Creates

When you run `install_serverpulse_agent.sh`, it creates on your Linux system:

```
/opt/serverpulse-agent/
├── serverpulse_agent.py    # Complete monitoring agent (auto-generated)
├── config.yml              # Configuration file
├── test_agent.py           # Testing script (auto-generated)  
├── venv/                   # Python virtual environment
│   ├── bin/python3         # Isolated Python interpreter
│   └── lib/                # All required packages (psutil, requests, etc.)
└── logs/
    └── agent.log          # Agent log file

/etc/systemd/system/
└── serverpulse-agent.service   # Systemd service file
```

## Features Built Into the Agent

The generated agent includes all functionality:

✅ **System Monitoring** - CPU, memory, disk, network metrics  
✅ **Service Monitoring** - Apache, Nginx, MySQL, Docker, SSH status  
✅ **Crash Detection** - System log monitoring for errors  
✅ **API Communication** - Secure HTTPS communication with ServerPulse  
✅ **Auto-Recovery** - Restarts automatically if it crashes  
✅ **Graceful Shutdown** - Sends offline status when shutting down  
✅ **Built-in Testing** - Test script to verify everything works  

## Installation Process

1. **Single Command**: `curl -sSL https://url/install_serverpulse_agent.sh | sudo bash`
2. **Configure**: Edit `/opt/serverpulse-agent/config.yml`  
3. **Start**: `sudo systemctl start serverpulse-agent`
4. **Test**: `sudo python3 /opt/serverpulse-agent/test_agent.py`

## Why This Approach?

- **Simplicity**: One file does everything
- **Reliability**: No dependency on external files or repositories
- **Portability**: Works on any Linux distribution
- **Self-Contained**: Includes all necessary code and configurations
- **Easy Deployment**: Single command installation

The installer script embeds all the Python code, configuration templates, service files, and test scripts needed for a complete monitoring solution.
