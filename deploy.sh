#!/bin/bash

# Health Check Server Deployment Script
# This script should be run on the Ubuntu VPS

set -e

echo "=== Health Check Server Deployment ==="

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "Go is not installed. Installing Go..."
    
    # Download and install Go
    GO_VERSION="1.21.5"
    wget -q https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin
    
    # Verify installation
    /usr/local/go/bin/go version
    echo "Go installed successfully"
else
    echo "Go is already installed"
    GO_CMD=$(which go)
fi

# Create dedicated user
echo "Creating healthcheck user..."
if ! id "healthcheck" &>/dev/null; then
    useradd -r -s /bin/false -d /var/lib/healthcheck -M healthcheck
    echo "User healthcheck created"
else
    echo "User healthcheck already exists"
fi

# Create directories
echo "Creating directories..."
mkdir -p /var/lib/healthcheck
mkdir -p /var/log/health-check-server
chown healthcheck:healthcheck /var/lib/healthcheck
chown healthcheck:healthcheck /var/log/health-check-server
chmod 750 /var/lib/healthcheck
chmod 750 /var/log/health-check-server

# Build the application
echo "Building health check server..."
if [ -n "$GO_CMD" ]; then
    $GO_CMD build -o /usr/local/bin/health-check-server main.go
else
    /usr/local/go/bin/go build -o /usr/local/bin/health-check-server main.go
fi

# Set permissions
echo "Setting permissions..."
chown root:healthcheck /usr/local/bin/health-check-server
chmod 750 /usr/local/bin/health-check-server

# Install systemd service
echo "Installing systemd service..."
cp health-check.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable health-check.service

# Configure firewall
echo "Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 8001/tcp
    echo "Firewall configured with ufw"
else
    echo "Warning: ufw not found. Please configure firewall manually to allow port 8001"
fi

# Start the service
echo "Starting health check service..."
systemctl start health-check.service

# Wait a moment for service to start
sleep 2

# Check service status
if systemctl is-active --quiet health-check.service; then
    echo "✅ Health check service started successfully"
else
    echo "❌ Health check service failed to start"
    echo "Checking logs:"
    journalctl -u health-check.service -n 20 --no-pager
    exit 1
fi

# Test the service
echo "Testing health check endpoint..."
if curl -f http://localhost:8001 > /dev/null 2>&1; then
    echo "✅ Health check endpoint is responding correctly"
else
    echo "❌ Health check endpoint is not responding"
    echo "Checking logs:"
    journalctl -u health-check.service -n 20 --no-pager
    exit 1
fi

echo ""
echo "=== Deployment Complete ==="
echo "Health check server is running on port 8001"
echo ""
echo "Useful commands:"
echo "  Check status: systemctl status health-check-server"
echo "  View logs: journalctl -u health-check-server -f"
echo "  Test endpoint: curl http://localhost:8001"
echo ""
echo "Service logs location: systemd journal"
echo "Binary location: /usr/local/bin/health-check-server"
echo "Service file: /etc/systemd/system/health-check.service"