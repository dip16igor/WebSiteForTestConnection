#!/bin/bash

# Health Check Server Simple Deployment Script
# This script deploys the health check server with MQTT integration
# Should be run on Ubuntu VPS

set -e

echo "=== Health Check Server Deployment ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to print info message
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Configuration variables
BINARY_NAME="health-check-server"
CONFIG_DIR="/etc/health-check-server"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/health-check.service"

# Step 1: Create backup of current binary
echo "Step 1: Creating backup of current binary..."
if [ -f /usr/local/bin/$BINARY_NAME ]; then
    BACKUP_FILE="/usr/local/bin/$BINARY_NAME.backup.$(date +%Y%m%d_%H%M%S)"
    cp /usr/local/bin/$BINARY_NAME "$BACKUP_FILE"
    print_success "Backup created: $BACKUP_FILE"
else
    print_warning "No existing binary found, skipping backup"
fi
echo ""

# Step 2: Create configuration directory
echo "Step 2: Creating configuration directory..."
mkdir -p "$CONFIG_DIR"
print_success "Configuration directory created/verified"
echo ""

# Step 3: Create configuration file
echo "Step 3: Creating configuration file..."
cat > "$CONFIG_FILE" << 'EOF'
# MQTT Configuration for Health Check Server
# Update with your MQTT broker settings

mqtt:
  # MQTT broker address (tcp://hostname:port)
  broker: "tcp://78.29.40.170:1883"
  
  # MQTT client ID (must be unique)
  client_id: "health-check-server"
  
  # Authentication credentials
  username: ""
  password: ""
  
  # Quality of Service level (0, 1, or 2)
  qos: 1
  
  # Whether to retain messages on the broker
  retain: false
  
  # Connection timeout in seconds
  connect_timeout: 10
  
  # Gate configuration: topic and payload for each gate value
  # Both gates publish to the same topic: GateControl/Gate
  gates:
    gate1:
      topic: "GateControl/Gate"
      payload: "179226315200"
    gate2:
      topic: "GateControl/Gate"
      payload: "279226315200"
EOF

print_success "Configuration file created"
echo ""

# Step 4: Set correct permissions on config file
echo "Step 4: Setting permissions on configuration file..."
chmod 600 "$CONFIG_FILE"
chown healthcheck:healthcheck "$CONFIG_FILE"
print_success "Permissions set to 600 and ownership to healthcheck:healthcheck"
echo ""

# Step 5: Copy new binary
echo "Step 5: Copying new binary..."
if [ -f $BINARY_NAME ]; then
    cp $BINARY_NAME /usr/local/bin/
    chmod +x /usr/local/bin/$BINARY_NAME
    chown root:healthcheck /usr/local/bin/$BINARY_NAME
    print_success "New binary copied and permissions set"
else
    print_error "$BINARY_NAME binary not found in current directory"
    echo "Please ensure $BINARY_NAME is compiled and in the same directory as this script"
    exit 1
fi
echo ""

# Step 6: Copy systemd service file
echo "Step 6: Copying systemd service file..."
if [ -f health-check.service ]; then
    cp health-check.service "$SERVICE_FILE"
    systemctl daemon-reload
    print_success "Systemd service file installed and reloaded"
else
    print_error "health-check.service not found in current directory"
    exit 1
fi
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
    journalctl -u health-check.service -n 20 --no-pager
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
    journalctl -u health-check.service -n 20 --no-pager
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
journalctl -u health-check.service -n 10 --no-pager
echo ""

# Step 12: Display service information
echo "Step 12: Service information..."
echo ""
systemctl status health-check.service --no-pager
echo ""

echo "=== Deployment Complete ==="
echo ""
echo "Health check server is running on port 8001"
echo ""
echo "Useful commands:"
echo "  Check status: systemctl status health-check-server"
echo "  View logs: journalctl -u health-check-server -f"
echo "  Restart service: systemctl restart health-check-server"
echo "  Stop service: systemctl stop health-check-server"
echo "  Edit config: nano /etc/health-check-server/config.yaml"
echo ""
echo "Configuration file location: $CONFIG_FILE"
echo "Binary location: /usr/local/bin/$BINARY_NAME"
echo "Service file: $SERVICE_FILE"
echo ""
