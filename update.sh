#!/bin/bash

# Health Check Server Update Script
# This script updates the health check server with new binary and configuration
# Should be run on Ubuntu VPS

set -e

echo "=== Health Check Server Update ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Function to print success message
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print error message
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Step 1: Create backup of current binary
echo "Step 1: Creating backup of current binary..."
if [ -f /usr/local/bin/health-check-server ]; then
    BACKUP_FILE="/usr/local/bin/health-check-server.backup.$(date +%Y%m%d_%H%M%S)"
    cp /usr/local/bin/health-check-server "$BACKUP_FILE"
    print_success "Backup created: $BACKUP_FILE"
else
    print_warning "No existing binary found, skipping backup"
fi
echo ""

# Step 2: Create configuration directory
echo "Step 2: Creating configuration directory..."
mkdir -p /etc/health-check-server
print_success "Configuration directory created/verified"
echo ""

# Step 3: Copy new configuration file
echo "Step 3: Copying new configuration file..."
if [ -f config.yaml ]; then
    cp config.yaml /etc/health-check-server/config.yaml
    print_success "Configuration file copied"
else
    print_error "config.yaml not found in current directory"
    echo "Please ensure config.yaml exists in the same directory as this script"
    exit 1
fi
echo ""

# Step 4: Set correct permissions on config file
echo "Step 4: Setting permissions on configuration file..."
chmod 600 /etc/health-check-server/config.yaml
chown healthcheck:healthcheck /etc/health-check-server/config.yaml
print_success "Permissions set to 600 and ownership to healthcheck:healthcheck"
echo ""

# Step 5: Copy new binary
echo "Step 5: Copying new binary..."
if [ -f health-check-server ]; then
    cp health-check-server /usr/local/bin/health-check-server
    chmod +x /usr/local/bin/health-check-server
    chown root:healthcheck /usr/local/bin/health-check-server
    print_success "New binary copied and permissions set"
else
    print_error "health-check-server binary not found in current directory"
    echo "Please ensure health-check-server is compiled and in the same directory as this script"
    exit 1
fi
echo ""

# Step 6: Reload systemd daemon
echo "Step 6: Reloading systemd daemon..."
systemctl daemon-reload
print_success "Systemd daemon reloaded"
echo ""

# Step 7: Restart service
echo "Step 7: Restarting health check service..."
systemctl restart health-check.service
sleep 3
echo ""

# Step 8: Check service status
echo "Step 8: Checking service status..."
if systemctl is-active --quiet health-check.service; then
    print_success "Health check service is running"
else
    print_error "Health check service failed to start"
    echo ""
    echo "Checking logs for errors:"
    journalctl -u health-check-server -n 20 --no-pager
    exit 1
fi
echo ""

# Step 9: Test health check endpoint
echo "Step 9: Testing health check endpoint..."
if curl -f --max-time 5 http://localhost:8001 > /dev/null 2>&1; then
    print_success "Health check endpoint is responding correctly"
else
    print_error "Health check endpoint is not responding"
    echo ""
    echo "Checking logs:"
    journalctl -u health-check-server -n 20 --no-pager
    exit 1
fi
echo ""

# Step 10: Test MQTT publish endpoint
echo "Step 10: Testing MQTT publish endpoint..."

# Test gate1
echo "Testing gate1..."
if curl -f -X GET http://localhost:8001/mqtt \
    -H "Content-Type: application/json" \
    -d '{"gate": "gate1"}' \
    --max-time 5 > /dev/null 2>&1; then
    print_success "MQTT publish for gate1 is working"
else
    print_warning "MQTT publish for gate1 failed (may be normal if MQTT broker is not configured)"
fi

# Test gate2
echo "Testing gate2..."
if curl -f -X GET http://localhost:8001/mqtt \
    -H "Content-Type: application/json" \
    -d '{"gate": "gate2"}' \
    --max-time 5 > /dev/null 2>&1; then
    print_success "MQTT publish for gate2 is working"
else
    print_warning "MQTT publish for gate2 failed (may be normal if MQTT broker is not configured)"
fi
echo ""

# Step 11: Display recent logs
echo "Step 11: Displaying recent logs..."
echo "Recent health check server logs:"
journalctl -u health-check-server -n 10 --no-pager
echo ""

# Step 12: Display service information
echo "Step 12: Service information..."
echo ""
systemctl status health-check.service --no-pager
echo ""

echo "=== Update Complete ==="
echo ""
echo "Useful commands:"
echo "  Check status: systemctl status health-check-server"
echo "  View logs: journalctl -u health-check-server -f"
echo "  Restart service: systemctl restart health-check-server"
echo "  Stop service: systemctl stop health-check-server"
echo ""
echo "Configuration file location: /etc/health-check-server/config.yaml"
echo "Binary location: /usr/local/bin/health-check-server"
echo ""
