# Makefile for ServerPulse Agent

.PHONY: help install test clean dev-install lint format

# Default target
help:
	@echo "ServerPulse Agent - Available commands:"
	@echo ""
	@echo "  install       Install the agent system-wide"
	@echo "  dev-install   Install for development"
	@echo "  test          Run tests"
	@echo "  lint          Run linting checks"
	@echo "  format        Format code"
	@echo "  clean         Clean build artifacts"
	@echo "  package       Create distribution package"
	@echo ""

# Install system-wide (requires root)
install:
	@echo "Installing ServerPulse Agent..."
	sudo ./install.sh

# Development installation
dev-install:
	@echo "Installing for development..."
	pip3 install --user -e .
	pip3 install --user pytest flake8 black

# Run tests
test:
	@echo "Running tests..."
	python3 test_agent.py
	@if command -v pytest >/dev/null 2>&1; then \
		echo "Running pytest..."; \
		pytest tests/ -v; \
	fi

# Lint code
lint:
	@echo "Running linting checks..."
	@if command -v flake8 >/dev/null 2>&1; then \
		flake8 --max-line-length=100 --ignore=E203,W503 .; \
	else \
		echo "flake8 not installed, skipping lint checks"; \
	fi

# Format code
format:
	@echo "Formatting code..."
	@if command -v black >/dev/null 2>&1; then \
		black --line-length=100 .; \
	else \
		echo "black not installed, skipping code formatting"; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

# Create distribution package
package: clean
	@echo "Creating distribution package..."
	python3 setup.py sdist bdist_wheel

# Quick start for development
dev: dev-install test
	@echo "Development setup complete!"

# Check agent status (if installed)
status:
	@if systemctl is-active --quiet serverpulse-agent; then \
		echo "Agent is running"; \
		systemctl status serverpulse-agent; \
	else \
		echo "Agent is not running"; \
	fi

# View agent logs
logs:
	@if [ -f /var/log/serverpulse-agent.log ]; then \
		tail -f /var/log/serverpulse-agent.log; \
	else \
		journalctl -u serverpulse-agent -f; \
	fi
