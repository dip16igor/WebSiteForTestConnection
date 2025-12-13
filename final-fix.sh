#!/bin/bash

# Final fix script - handles all service name issues
set -e

echo "=== Final Health Check Server Fix ==="

# 1. Check what service files exist
echo "1. Checking service files..."
if [ -f /etc/systemd/system/health-check.service ]; then
    echo "   Found: health-check.service"
    SERVICE_NAME="health-check"
elif [ -f /etc/systemd/system/health-check-server.service ]; then
    echo "   Found: health-check-server.service"
    SERVICE_NAME="health-check-server"
else
    echo "   No service file found, installing health-check-server.service..."
    sudo cp health-check-server.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable health-check-server.service
    SERVICE_NAME="health-check-server"
    echo "   ✅ Installed health-check-server.service"
fi

# 2. Remove old service if it exists
if [ -f /etc/systemd/system/health-check.service ] && [ "$SERVICE_NAME" = "health-check-server" ]; then
    echo "   Removing old service..."
    sudo systemctl stop health-check.service 2>/dev/null || true
    sudo systemctl disable health-check.service 2>/dev/null || true
    sudo rm /etc/systemd/system/health-check.service
    sudo systemctl daemon-reload
    echo "   ✅ Removed old service"
fi

# 3. Rebuild application
echo "2. Rebuilding application..."
cd /tmp
/usr/local/go/bin/go build -o /usr/local/bin/health-check-server main.go
sudo chown root:healthcheck /usr/local/bin/health-check-server
sudo chmod 750 /usr/local/bin/health-check-server
echo "   ✅ Application rebuilt"

# 4. Start the correct service
echo "3. Starting service: $SERVICE_NAME"
sudo systemctl start $SERVICE_NAME
sleep 3

# 5. Check service status
echo "4. Checking service status..."
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "   ✅ Service $SERVICE_NAME is running"
else
    echo "   ❌ Service $SERVICE_NAME failed to start"
    echo "   Checking logs:"
    sudo journalctl -u $SERVICE_NAME -n 20 --no-pager
    exit 1
fi

# 6. Test basic functionality
echo "5. Testing basic functionality..."
if curl -s http://localhost:8001 | grep -q "OK"; then
    echo "   ✅ Basic functionality works"
else
    echo "   ❌ Basic functionality failed"
    exit 1
fi

# 7. Test security headers
echo "6. Testing security headers..."

# Test all headers at once
headers=$(curl -s -I http://localhost:8001 2>/dev/null)

# Check X-Content-Type-Options
if echo "$headers" | grep -qi "X-Content-Type-Options: nosniff"; then
    echo "   ✅ X-Content-Type-Options: nosniff"
else
    echo "   ❌ X-Content-Type-Options missing"
fi

# Check X-Frame-Options
if echo "$headers" | grep -qi "X-Frame-Options: DENY"; then
    echo "   ✅ X-Frame-Options: DENY"
else
    echo "   ❌ X-Frame-Options missing"
fi

# Check X-XSS-Protection
if echo "$headers" | grep -qi "X-XSS-Protection: 1; mode=block"; then
    echo "   ✅ X-XSS-Protection: 1; mode=block"
else
    echo "   ❌ X-XSS-Protection missing"
fi

# 8. Test logging
echo "7. Testing logging..."
curl -s http://localhost:8001 > /dev/null
sleep 2

if journalctl -u $SERVICE_NAME --since "1 minute ago" | grep -q "Health check request processed"; then
    echo "   ✅ Logs are being generated"
else
    echo "   ❌ Logs not found"
    echo "   Checking recent logs:"
    sudo journalctl -u $SERVICE_NAME --since "2 minutes ago" --no-pager
fi

# 9. Test rate limiting
echo "8. Testing rate limiting..."
rate_limit_hits=0
for i in {1..12}; do
    status=$(curl -s -w "%{http_code}" http://localhost:8001 2>/dev/null | tail -n 1)
    if [ "$status" = "429" ]; then
        rate_limit_hits=$((rate_limit_hits + 1))
    fi
    sleep 0.1
done

if [ $rate_limit_hits -gt 0 ]; then
    echo "   ✅ Rate limiting works ($rate_limit_hits requests blocked)"
else
    echo "   ❌ Rate limiting not working"
fi

# 10. Update test script with correct service name
echo "9. Updating test script..."
sed -i "s/health-check-server/$SERVICE_NAME/g" test.sh
echo "   ✅ Updated test script with service name: $SERVICE_NAME"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Service name: $SERVICE_NAME"
echo "Service status: $(systemctl is-active $SERVICE_NAME)"
echo ""
echo "Run tests:"
echo "   ./test.sh"
echo ""
echo "View logs:"
echo "   sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "Check service:"
echo "   sudo systemctl status $SERVICE_NAME"