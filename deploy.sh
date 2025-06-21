#!/bin/bash

# ServerPulse Agent - One-Line Deployment Script
# Run this directly on your Ubuntu VM

set -e

echo "🚀 ServerPulse Agent Deployment Starting..."

# Check for sudo
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script must be run with sudo"
    echo "Usage: curl -sSL https://raw.githubusercontent.com/your-repo/serverpulse-agent/main/deploy.sh | sudo bash"
    exit 1
fi

# Create temporary directory
TEMP_DIR="/tmp/serverpulse-agent-$$"
mkdir -p $TEMP_DIR
cd $TEMP_DIR

echo "📥 Downloading agent files..."
# Download the repository
curl -sSL https://github.com/your-repo/serverpulse-agent/archive/main.tar.gz | tar -xz
cd serverpulse-agent-main

echo "🔧 Running installation..."
# Make installer executable and run it
chmod +x quick_install.sh
./quick_install.sh

echo "🧹 Cleaning up..."
cd /
rm -rf $TEMP_DIR

echo ""
echo "✅ ServerPulse Agent deployed successfully!"
echo ""
echo "Next steps:"
echo "1. Configure: sudo nano /opt/serverpulse-agent/config.yml"
echo "2. Start: sudo systemctl start serverpulse-agent"
echo "3. Test: sudo python3 /opt/serverpulse-agent/test_installation.py"
