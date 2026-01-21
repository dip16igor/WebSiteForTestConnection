#!/bin/bash

# Health Check Server Auto-Deployment Script
# This script downloads, builds, and deploys the health check server
# Should be run on Ubuntu VPS

set -e

echo "=== Health Check Server Auto-Deployment ==="
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
REPO_URL="https://github.com/your-org/health-check-server.git"  # Change to your repo
REPO_DIR="/opt/health-check-server"
BINARY_NAME="health-check-server"
CONFIG_DIR="/etc/health-check-server"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/health-check.service"

# Step 1: Install dependencies
echo "Step 1: Installing dependencies..."
print_info "Checking for Go..."
if ! command -v go &> /dev/null; then
    print_info "Go is not installed. Installing Go..."
    
    # Download and install Go
    GO_VERSION="1.21.5"
    cd /tmp
    wget -q https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz
    
    if [ -f "go${GO_VERSION}.linux-amd64.tar.gz" ]; then
        tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
        
        # Add Go to PATH
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        export PATH=$PATH:/usr/local/go/bin
        
        # Verify installation
        /usr/local/go/bin/go version
        print_success "Go installed successfully"
    else
        print_error "Failed to download Go"
        exit 1
    fi
else
    print_success "Go is already installed"
    GO_CMD=$(which go)
fi

# Step 2: Clone or update repository
echo ""
echo "Step 2: Cloning/updating repository..."
if [ -d "$REPO_DIR" ]; then
    print_info "Repository exists, updating..."
    cd "$REPO_DIR"
    git pull || print_warning "Git pull failed, continuing..."
else
    print_info "Cloning repository..."
    git clone "$REPO_URL" "$REPO_DIR" || {
        print_error "Failed to clone repository"
        exit 1
    }
    cd "$REPO_DIR"
fi
print_success "Repository ready"

# Step 3: Download Go dependencies
echo ""
echo "Step 3: Downloading Go dependencies..."
cd "$REPO_DIR"
print_info "Running go mod download..."
$GO_CMD mod download || {
    print_error "Failed to download dependencies"
    exit 1
}
print_success "Dependencies downloaded"

# Step 4: Build binary
echo ""
echo "Step 4: Building binary..."
print_info "Compiling for Linux AMD64..."
$GO_CMD build -ldflags="-s -w" -o "$BINARY_NAME" main.go || {
    print_error "Failed to build binary"
    exit 1
}
print_success "Binary built successfully"

# Step 5: Create configuration directory
echo ""
echo "Step 5: Creating configuration directory..."
mkdir -p "$CONFIG_DIR"
print_success "Configuration directory created"

# Step 6: Create configuration file
echo ""
echo "Step 6: Creating configuration file..."
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

# Set permissions on config file
chmod 600 "$CONFIG_FILE"
chown healthcheck:healthcheck "$CONFIG_FILE"
print_success "Configuration file created at $CONFIG_FILE"
print_warning "Please update MQTT broker settings in $CONFIG_FILE if needed"

# Step 7: Create healthcheck user if not exists
echo ""
echo "Step 7: Creating healthcheck user..."
if ! id "healthcheck" &>/dev/null; then
    useradd -r -s /bin/false -d /var/lib/healthcheck -M healthcheck
    print_success "User healthcheck created"
else
    print_info "User healthcheck already exists"
fi

# Step 8: Create log directory
echo ""
echo "Step 8: Creating log directory..."
mkdir -p /var/log/health-check-server
chown healthcheck:healthcheck /var/log/health-check-server
chmod 750 /var/log/health-check-server
print_success "Log directory created"

# Step 9: Install binary
echo ""
echo "Step 9: Installing binary..."
cp "$REPO_DIR/$BINARY_NAME" /usr/local/bin/
chmod +x /usr/local/bin/$BINARY_NAME
chown root:healthcheck /usr/local/bin/$BINARY_NAME
print_success "Binary installed to /usr/local/bin/$BINARY_NAME"

# Step 10: Install systemd service
echo ""
echo "Step 10: Installing systemd service..."
if [ -f "$SERVICE_FILE" ]; then
    print_info "Service file exists, backing up..."
    cp "$SERVICE_FILE" "$SERVICE_FILE.backup"
fi

cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Health Check Web Server with MQTT Integration
Documentation=https://github.com/your-org/health-check-server
After=network.target
Wants=network.target

[Service]
Type=simple
User=healthcheck
Group=healthcheck
WorkingDirectory=$CONFIG_DIR
ExecStart=/usr/local/bin/health-check-server
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=health-check-server

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$CONFIG_DIR /var/log/health-check-server
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
PrivateDevices=true
ProtectKernelLogs=true
ProtectClock=true

# Network settings - allow outbound MQTT connections
# Note: Update IPAddressAllow if your MQTT broker is on a specific network

# Resource limits
LimitNOFILE=65536
MemoryMax=50M
CPUQuota=10%

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable health-check.service
print_success "Systemd service installed and enabled"

# Step 11: Configure firewall
echo ""
echo "Step 11: Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 8001/tcp
    print_success "Firewall configured with ufw (port 8001)"
else
    print_warning "ufw not found. Please configure firewall manually to allow port 8001"
fi

# Step 12: Start service
echo ""
echo "Step 12: Starting health check service..."
systemctl restart health-check.service
sleep 3

# Step 13: Check service status
echo ""
echo "Step 13: Checking service status..."
if systemctl is-active --quiet health-check.service; then
    print_success "Health check service is running"
else
    print_error "Health check service failed to start"
    echo ""
    echo "Checking logs:"
    journalctl -u health-check.service -n 20 --no-pager
    exit 1
fi

# Step 14: Test health check endpoint
echo ""
echo "Step 14: Testing health check endpoint..."
if curl -f --max-time 5 http://localhost:8001 > /dev/null 2>&1; then
    print_success "Health check endpoint is responding correctly"
else
    print_error "Health check endpoint is not responding"
    echo ""
    echo "Checking logs:"
    journalctl -u health-check.service -n 20 --no-pager
    exit 1
fi

# Step 15: Test MQTT publish endpoint
echo ""
echo "Step 15: Testing MQTT publish endpoint..."

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

# Step 16: Display recent logs
echo ""
echo "Step 16: Displaying recent logs..."
echo "Recent health check server logs:"
journalctl -u health-check.service -n 10 --no-pager

# Step 17: Display service information
echo ""
echo "Step 17: Service information..."
echo ""
systemctl status health-check.service --no-pager

echo ""
echo "=== Auto-Deployment Complete ==="
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
echo "Repository location: $REPO_DIR"
echo ""
