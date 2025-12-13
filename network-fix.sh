#!/bin/bash

# Network connectivity fix script for health check server
set -e

echo "=== Network Connectivity Fix ==="

VPS_IP="109.69.19.36"
PORT="8001"

# 1. Check if service is running
echo "1. Checking service status..."
if systemctl is-active --quiet health-check-server; then
    echo "   ✅ Service is running"
else
    echo "   ❌ Service is not running, starting..."
    sudo systemctl start health-check-server
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
    echo "   All listening ports:"
    sudo netstat -tlnp
    exit 1
fi

# 3. Check firewall status
echo "3. Checking firewall configuration..."
if command -v ufw &> /dev/null; then
    echo "   UFW firewall status:"
    sudo ufw status verbose
    
    echo ""
    echo "   Checking UFW rules for port $PORT..."
    if sudo ufw status | grep -q "$PORT/tcp"; then
        echo "   ✅ Port $PORT is allowed in UFW"
    else
        echo "   ❌ Port $PORT is NOT allowed in UFW"
        echo "   Adding rule..."
        sudo ufw allow $PORT/tcp
        echo "   ✅ Port $PORT allowed in UFW"
    fi
else
    echo "   UFW not found, checking iptables..."
    if sudo iptables -L -n | grep -q "$PORT"; then
        echo "   ✅ Port $PORT is allowed in iptables"
    else
        echo "   ❌ Port $PORT is NOT allowed in iptables"
        echo "   Adding rule..."
        sudo iptables -A INPUT -p tcp --dport $PORT -j ACCEPT
        echo "   ✅ Port $PORT allowed in iptables"
    fi
fi

# 4. Test local connectivity
echo "4. Testing local connectivity..."
if curl -s --connect-timeout 5 http://localhost:$PORT | grep -q "OK"; then
    echo "   ✅ Local connectivity works"
else
    echo "   ❌ Local connectivity failed"
    exit 1
fi

# 5. Test internal IP connectivity
echo "5. Testing internal IP connectivity..."
INTERNAL_IP=$(hostname -I | awk '{print $1}')
if curl -s --connect-timeout 5 http://$INTERNAL_IP:$PORT | grep -q "OK"; then
    echo "   ✅ Internal IP ($INTERNAL_IP) connectivity works"
else
    echo "   ❌ Internal IP ($INTERNAL_IP) connectivity failed"
fi

# 6. Test external IP connectivity
echo "6. Testing external IP connectivity..."
if curl -s --connect-timeout 5 http://$VPS_IP:$PORT | grep -q "OK"; then
    echo "   ✅ External IP ($VPS_IP) connectivity works"
else
    echo "   ❌ External IP ($VPS_IP) connectivity failed"
    echo "   This might be a firewall or network issue"
fi

# 7. Check systemd service network restrictions
echo "7. Checking systemd network restrictions..."
if [ -f /etc/systemd/system/health-check-server.service ]; then
    echo "   Checking service file network settings..."
    if grep -q "IPAddressDeny=any" /etc/systemd/system/health-check-server.service; then
        echo "   ⚠️  Found IPAddressDeny=any in service file"
        echo "   This might be blocking external connections"
        echo ""
        echo "   Creating updated service file without network restrictions..."
        
        # Create backup
        sudo cp /etc/systemd/system/health-check-server.service /etc/systemd/system/health-check-server.service.backup
        
        # Remove network restrictions
        sudo sed -i '/^# Network settings$/,$d' /etc/systemd/system/health-check-server.service
        sudo systemctl daemon-reload
        sudo systemctl restart health-check-server
        sleep 2
        
        echo "   ✅ Network restrictions removed, service restarted"
    else
        echo "   ✅ No blocking network restrictions found"
    fi
fi

# 8. Test after fixes
echo "8. Testing connectivity after fixes..."
sleep 2

if curl -s --connect-timeout 10 http://$VPS_IP:$PORT | grep -q "OK"; then
    echo "   ✅ External connectivity now works!"
    echo "   Server is accessible from internet"
else
    echo "   ❌ External connectivity still fails"
    echo ""
    echo "   Manual troubleshooting steps:"
    echo "   1. Check cloud provider firewall settings"
    echo "   2. Verify port $PORT is open in cloud console"
    echo "   3. Check if VPS has public IP assignment"
    echo "   4. Try: curl -v http://$VPS_IP:$PORT"
fi

# 9. Show current status
echo ""
echo "=== Current Status ==="
echo "Service: $(systemctl is-active health-check-server)"
echo "Port $PORT listening: $(sudo netstat -tlnp | grep -q ":$PORT " && echo "Yes" || echo "No")"
echo "External IP: $VPS_IP"
echo "Internal IP: $(hostname -I | awk '{print $1}')"

# 10. Test commands for manual verification
echo ""
echo "=== Manual Test Commands ==="
echo "Test local:"
echo "   curl http://localhost:$PORT"
echo ""
echo "Test internal IP:"
echo "   curl http://$(hostname -I | awk '{print $1}'):$PORT"
echo ""
echo "Test external IP:"
echo "   curl http://$VPS_IP:$PORT"
echo ""
echo "Verbose test:"
echo "   curl -v http://$VPS_IP:$PORT"
echo ""
echo "Port scan:"
echo "   sudo nmap -p $PORT $VPS_IP"
echo ""
echo "Check service logs:"
echo "   sudo journalctl -u health-check-server -f"