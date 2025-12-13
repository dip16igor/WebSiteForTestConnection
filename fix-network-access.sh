#!/bin/bash

# Fix network access for health check server
set -e

echo "=== Network Access Fix ==="

VPS_IP="109.69.19.36"
PORT="8001"
SERVICE_NAME="health-check"

# 1. Check service status
echo "1. Checking service status..."
if systemctl is-active --quiet $SERVICE_NAME; then
    echo "   ✅ Service $SERVICE_NAME is running"
else
    echo "   ❌ Service $SERVICE_NAME is not running"
    echo "   Starting service..."
    sudo systemctl start $SERVICE_NAME
    sleep 2
fi

# 2. Check if port is listening
echo "2. Checking if port $PORT is listening..."
if sudo netstat -tlnp | grep -q ":$PORT "; then
    echo "   ✅ Port $PORT is listening"
    echo "   Details:"
    sudo netstat -tlnp | grep ":$PORT"
else
    echo "   ❌ Port $PORT is not listening"
    exit 1
fi

# 3. Check and fix firewall
echo "3. Checking and fixing firewall..."
if command -v ufw &> /dev/null; then
    echo "   UFW status:"
    sudo ufw status
    
    if ! sudo ufw status | grep -q "$PORT/tcp.*ALLOW"; then
        echo "   Adding UFW rule for port $PORT..."
        sudo ufw allow $PORT/tcp
        echo "   ✅ Port $PORT allowed in UFW"
    else
        echo "   ✅ Port $PORT already allowed in UFW"
    fi
else
    echo "   UFW not found, checking iptables..."
    if ! sudo iptables -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null; then
        echo "   Adding iptables rule for port $PORT..."
        sudo iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
        echo "   ✅ Port $PORT allowed in iptables"
    else
        echo "   ✅ Port $PORT already allowed in iptables"
    fi
fi

# 4. Check and fix systemd service network restrictions
echo "4. Checking systemd service network restrictions..."
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

if [ -f "$SERVICE_FILE" ]; then
    echo "   Service file: $SERVICE_FILE"
    
    # Check for network restrictions
    if grep -q "IPAddressDeny=any" "$SERVICE_FILE"; then
        echo "   ⚠️  Found network restrictions in service file"
        echo "   Creating backup..."
        sudo cp "$SERVICE_FILE" "$SERVICE_FILE.backup"
        
        echo "   Removing network restrictions..."
        # Create temporary file without network restrictions
        sudo sed '/^# Network settings$/,$d' "$SERVICE_FILE" > /tmp/service_temp
        
        # Write back the service file without network restrictions
        sudo head -n -18 "$SERVICE_FILE" > /tmp/service_clean
        sudo mv /tmp/service_clean "$SERVICE_FILE"
        
        sudo systemctl daemon-reload
        sudo systemctl restart $SERVICE_NAME
        sleep 3
        
        echo "   ✅ Network restrictions removed"
    else
        echo "   ✅ No network restrictions found"
    fi
else
    echo "   ❌ Service file not found: $SERVICE_FILE"
fi

# 5. Test connectivity
echo "5. Testing connectivity..."

# Local test
echo "   Testing localhost..."
if curl -s --connect-timeout 5 http://localhost:$PORT | grep -q "OK"; then
    echo "   ✅ Local connectivity works"
else
    echo "   ❌ Local connectivity failed"
fi

# Internal IP test
INTERNAL_IP=$(hostname -I | awk '{print $1}')
echo "   Testing internal IP ($INTERNAL_IP)..."
if curl -s --connect-timeout 5 http://$INTERNAL_IP:$PORT | grep -q "OK"; then
    echo "   ✅ Internal IP connectivity works"
else
    echo "   ❌ Internal IP connectivity failed"
fi

# External IP test
echo "   Testing external IP ($VPS_IP)..."
if curl -s --connect-timeout 10 http://$VPS_IP:$PORT | grep -q "OK"; then
    echo "   ✅ External IP connectivity works!"
    SUCCESS=true
else
    echo "   ❌ External IP connectivity failed"
    SUCCESS=false
fi

# 6. Final status
echo ""
echo "=== Final Status ==="
echo "Service: $SERVICE_NAME - $(systemctl is-active $SERVICE_NAME)"
echo "Port $PORT: $(sudo netstat -tlnp | grep -q ":$PORT " && echo "Listening" || echo "Not listening")"
echo "External access: $([ "$SUCCESS" = true ] && echo "✅ Working" || echo "❌ Failed")"

# 7. Next steps
if [ "$SUCCESS" = true ]; then
    echo ""
    echo "🎉 SUCCESS! Server is accessible from internet."
    echo ""
    echo "Test from external location:"
    echo "   curl http://$VPS_IP:$PORT"
    echo ""
    echo "Monitor logs:"
    echo "   sudo journalctl -u $SERVICE_NAME -f"
else
    echo ""
    echo "❌ External access still not working."
    echo ""
    echo "Possible causes:"
    echo "1. Cloud provider firewall (check your VPS provider console)"
    echo "2. Security groups (AWS, DigitalOcean, etc.)"
    echo "3. NAT/Router issues"
    echo "4. IP not properly assigned"
    echo ""
    echo "Manual troubleshooting:"
    echo "   curl -v http://$VPS_IP:$PORT"
    echo "   sudo nmap -p $PORT $VPS_IP"
    echo "   telnet $VPS_IP $PORT"
fi