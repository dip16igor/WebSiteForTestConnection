#!/bin/bash

# Fix deployment issues script
# This script fixes common issues after initial deployment

set -e

echo "=== Fixing Health Check Server Deployment Issues ==="

# 1. Rebuild and restart service with fixed code
echo "1. Rebuilding application with fixes..."
/usr/local/go/bin/go build -o /usr/local/bin/health-check-server main.go
sudo chown root:healthcheck /usr/local/bin/health-check-server
sudo chmod 750 /usr/local/bin/health-check-server

# 2. Restart service
echo "2. Restarting service..."
sudo systemctl restart health-check-server
sleep 2

# 3. Check service status
echo "3. Checking service status..."
if systemctl is-active --quiet health-check-server; then
    echo "   ✅ Service is running"
else
    echo "   ❌ Service is not running"
    echo "   Checking logs:"
    sudo journalctl -u health-check-server -n 10 --no-pager
    exit 1
fi

# 4. Test headers manually
echo "4. Testing security headers..."
echo "   Testing X-Content-Type-Options header:"
header_value=$(curl -s -I http://localhost:8001 2>/dev/null | grep -i "X-Content-Type-Options" | cut -d' ' -f2- | tr -d '\r\n')
if [ "$header_value" = "nosniff" ]; then
    echo "   ✅ X-Content-Type-Options: nosniff"
else
    echo "   ❌ X-Content-Type-Options: '$header_value' (expected: nosniff)"
fi

echo "   Testing X-Frame-Options header:"
header_value=$(curl -s -I http://localhost:8001 2>/dev/null | grep -i "X-Frame-Options" | cut -d' ' -f2- | tr -d '\r\n')
if [ "$header_value" = "DENY" ]; then
    echo "   ✅ X-Frame-Options: DENY"
else
    echo "   ❌ X-Frame-Options: '$header_value' (expected: DENY)"
fi

echo "   Testing X-XSS-Protection header:"
header_value=$(curl -s -I http://localhost:8001 2>/dev/null | grep -i "X-XSS-Protection" | cut -d' ' -f2- | tr -d '\r\n')
if [ "$header_value" = "1; mode=block" ]; then
    echo "   ✅ X-XSS-Protection: 1; mode=block"
else
    echo "   ❌ X-XSS-Protection: '$header_value' (expected: 1; mode=block)"
fi

# 5. Test logging
echo "5. Testing logging..."
curl -s http://localhost:8001 > /dev/null
sleep 1

# Check if logs are being captured
if journalctl -u health-check-server --since "30 seconds ago" | grep -q "Health check request processed"; then
    echo "   ✅ Logs are being generated and captured"
else
    echo "   ❌ Logs not found in journal"
    echo "   Checking recent logs:"
    sudo journalctl -u health-check-server --since "1 minute ago" --no-pager
fi

# 6. Test rate limiting
echo "6. Testing rate limiting..."
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

echo ""
echo "=== Fix Summary ==="
echo "1. Application rebuilt with logging fixes"
echo "2. Service restarted"
echo "3. Security headers tested"
echo "4. Logging functionality tested"
echo "5. Rate limiting tested"
echo ""
echo "If issues persist, check the service logs:"
echo "   sudo journalctl -u health-check-server -f"
echo ""
echo "Run the full test suite:"
echo "   ./test.sh"