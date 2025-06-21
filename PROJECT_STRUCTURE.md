# ServerPulse Agent Project Structure

```
serverpulse-agent/
├── serverpulse_agent.py          # Main agent application
├── agent_cli.py                  # Command-line interface
├── test_agent.py                 # Test script
├── requirements.txt              # Python dependencies
├── setup.py                      # Package setup script
├── Makefile                      # Development tasks
├── README.md                     # Project documentation
├── install.sh                    # Installation script
├── config.yml.example           # Example configuration
├── serverpulse-agent.service     # Systemd service file
├── collectors/                   # Data collection modules
│   ├── __init__.py
│   ├── system_metrics.py         # System metrics collector
│   ├── service_monitor.py        # Service monitoring
│   ├── crash_detector.py         # Crash detection
│   └── log_monitor.py            # Log file monitoring
├── communication/                # Communication modules
│   ├── __init__.py
│   └── api_client.py             # API client for ServerPulse
├── utils/                        # Utility modules
│   ├── __init__.py
│   ├── config.py                 # Configuration management
│   └── logger.py                 # Logging setup
└── tests/                        # Test files (create as needed)
    └── __init__.py
```

## Quick Start

1. **Clone/download the project**
2. **Install dependencies**: `pip3 install -r requirements.txt`
3. **Run tests**: `python3 test_agent.py`
4. **Configure**: Copy `config.yml.example` to `/etc/serverpulse-agent/config.yml` and edit
5. **Install**: Run `sudo ./install.sh` (on Linux)
6. **Start**: `sudo systemctl start serverpulse-agent`

## Development

- Use `make dev` for development setup
- Use `make test` to run tests
- Use `make lint` for code checking
- Use `make clean` to clean build artifacts

## Files Description

### Core Files
- `serverpulse_agent.py`: Main agent that orchestrates all monitoring
- `agent_cli.py`: CLI tool for testing and management
- `test_agent.py`: Comprehensive test suite

### Configuration
- `config.yml.example`: Template configuration file
- `requirements.txt`: Python package dependencies
- `setup.py`: Package installation configuration

### Installation
- `install.sh`: Automated installation script for Linux
- `serverpulse-agent.service`: Systemd service configuration
- `Makefile`: Development and build tasks

### Collectors
- `system_metrics.py`: CPU, memory, disk, network metrics
- `service_monitor.py`: Systemd service monitoring
- `crash_detector.py`: System crash and error detection
- `log_monitor.py`: Custom log file monitoring

### Communication
- `api_client.py`: HTTP client for ServerPulse API

### Utilities
- `config.py`: Configuration file management
- `logger.py`: Logging configuration and setup
