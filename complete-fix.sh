#!/bin/bash

# Complete fix script for health check server deployment
# This script addresses all deployment issues

set -e

echo "=== Complete Health Check Server Fix ==="

# 1. Check if service file exists and install it if needed
echo "1. Checking and installing systemd service..."
if [ ! -f /etc/systemd/system/health-check.service ]; then
    echo "   Service file not found, installing..."
    sudo cp health-check.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable health-check.service
    echo "   ✅ Service file installed"
else
    echo "   ✅ Service file exists"
fi

# 2. Rebuild application in proper directory
echo "2. Rebuilding application..."
cd /tmp
/usr/local/go/bin/go build -o /usr/local/bin/health-check-server main.go
sudo chown root:healthcheck /usr/local/bin/health-check-server
sudo chmod 750 /usr/local/bin/health-check-server
echo "   ✅ Application rebuilt"

# 3. Verify binary exists and is executable
if [ ! -f /usr/local/bin/health-check-server ]; then
    echo "   ❌ Binary not found at /usr/local/bin/health-check-server"
    exit 1
fi

# 4. Start service
echo "3. Starting service..."
sudo systemctl start health-check-server
sleep 3

# 5. Check service status
echo "4. Checking service status..."
if systemctl is-active --quiet health-check-server; then
    echo "   ✅ Service is running"
else
    echo "   ❌ Service failed to start"
    echo "   Checking service logs:"
    sudo journalctl -u health-check.service -n 20 --no-pager
    echo ""
    echo "   Checking binary permissions:"
    ls -la /usr/local/bin/health-check-server
    echo ""
    echo "   Checking user:"
    id healthcheck || echo "   ❌ User healthcheck not found"
    exit 1
fi

# 6. Test basic functionality
echo "5. Testing basic functionality..."
if curl -s http://localhost:8001 | grep -q "OK"; then
    echo "   ✅ Basic functionality works"
else
    echo "   ❌ Basic functionality failed"
    echo "   Server response:"
    curl -v http://localhost:8001 2>&1 | head -20
    exit 1
fi

# 7. Test security headers
echo "6. Testing security headers..."

# Test X-Content-Type-Options
header_value=$(curl -s -I http://localhost:8001 2>/dev/null | grep -i "X-Content-Type-Options" | cut -d' ' -f2- | tr -d '\r\n')
if [ "$header_value" = "nosniff" ]; then
    echo "   ✅ X-Content-Type-Options: nosniff"
else
    echo "   ❌ X-Content-Type-Options: '$header_value' (expected: nosniff)"
fi

# Test X-Frame-Options
header_value=$(curl -s -I http://localhost:8001 2>/dev/null | grep -i "X-Frame-Options" | cut -d' ' -f2- | tr -d '\r\n')
if [ "$header_value" = "DENY" ]; then
    echo "   ✅ X-Frame-Options: DENY"
else
    echo "   ❌ X-Frame-Options: '$header_value' (expected: DENY)"
    echo "   Debug: All headers:"
    curl -s -I http://localhost:8001 2>/dev/null
fi

# Test X-XSS-Protection
header_value=$(curl -s -I http://localhost:8001 2>/dev/null | grep -i "X-XSS-Protection" | cut -d' ' -f2- | tr -d '\r\n')
if [ "$header_value" = "1; mode=block" ]; then
    echo "   ✅ X-XSS-Protection: 1; mode=block"
else
    echo "   ❌ X-XSS-Protection: '$header_value' (expected: 1; mode=block)"
fi

# 8. Test logging
echo "7. Testing logging..."
curl -s http://localhost:8001 > /dev/null
sleep 2

# Check if logs are being captured
if journalctl -u health-check.service --since "1 minute ago" | grep -q "Health check request processed"; then
    echo "   ✅ Logs are being generated and captured"
else
    echo "   ❌ Logs not found in journal"
    echo "   Checking recent logs:"
    sudo journalctl -u health-check.service --since "2 minutes ago" --no-pager
    echo ""
    echo "   Manual log check:"
    sudo journalctl -u health-check.service -n 10 --no-pager
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
    echo "   ✅ Rate limiting is working ($rate_limit_hits requests blocked)"
else
    echo "   ❌ Rate limiting is not working"
fi

# 10. Final verification
echo "9. Final verification..."
echo "   Service status: $(systemctl is-active health-check-server)"
echo "   Service enabled: $(systemctl is-enabled health-check-server)"
echo "   Binary location: $(which health-check-server)"
echo "   Binary permissions: $(ls -la /usr/local/bin/health-check-server)"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "To run the full test suite:"
echo "   ./test.sh"
echo ""
echo "To view logs:"
echo "   sudo journalctl -u health-check.service -f"
echo ""
echo "To check service status:"
echo "   sudo systemctl status health-check.service"