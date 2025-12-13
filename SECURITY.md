# Security Hardening Guidelines

This document outlines security best practices and hardening guidelines for the Health Check Server deployment.

## System Security

### User Management

```bash
# Create dedicated non-privileged user
sudo useradd -r -s /bin/false -d /var/lib/healthcheck -M healthcheck

# Verify user creation
id healthcheck

# User should have:
# - No login shell (-s /bin/false)
# - No home directory (-M)
# - System user (-r)
# - Locked password
```

### File Permissions

```bash
# Set binary ownership and permissions
sudo chown root:healthcheck /usr/local/bin/health-check-server
sudo chmod 750 /usr/local/bin/health-check-server

# Set service file permissions
sudo chown root:root /etc/systemd/system/health-check.service
sudo chmod 644 /etc/systemd/system/health-check.service

# Verify permissions
ls -la /usr/local/bin/health-check-server
ls -la /etc/systemd/system/health-check.service
```

### Directory Structure

```bash
# Create log directory if needed
sudo mkdir -p /var/log/health-check-server
sudo chown healthcheck:healthcheck /var/log/health-check-server
sudo chmod 750 /var/log/health-check-server

# Create runtime directory
sudo mkdir -p /var/lib/healthcheck
sudo chown healthcheck:healthcheck /var/lib/healthcheck
sudo chmod 750 /var/lib/healthcheck
```

## Network Security

### Firewall Configuration

```bash
# Using UFW (Uncomplicated Firewall)
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (adjust port as needed)
sudo ufw allow 22/tcp

# Allow health check port (restrict if possible)
sudo ufw allow 8001/tcp

# For additional security, restrict to specific IPs
sudo ufw allow from 192.168.1.0/24 to any port 8001 proto tcp

# Check firewall status
sudo ufw status verbose
```

### iptables Rules (Alternative)

```bash
# Basic iptables rules
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8001 -j ACCEPT
sudo iptables -A INPUT -j DROP

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

### Network Hardening

```bash
# Disable unnecessary services
sudo systemctl disable apache2
sudo systemctl disable nginx
sudo systemctl disable mysql
sudo systemctl disable postfix

# Check listening ports
sudo netstat -tlnp
sudo ss -tlnp

# Monitor network connections
sudo watch 'sudo netstat -an | grep :8001'
```

## Service Security

### systemd Security Features

The service file includes comprehensive security settings:

```ini
# Process isolation
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
RemoveIPC=true
PrivateDevices=true
ProtectKernelLogs=true
ProtectClock=true

# Network restrictions
IPAddressDeny=any
IPAddressAllow=localhost
IPAddressAllow=::1

# Resource limits
LimitNOFILE=65536
MemoryMax=50M
CPUQuota=10%
```

### Additional Security Hardening

```bash
# Enable systemd security features
sudo systemctl edit health-check.service

# Add additional restrictions:
[Service]
# Additional security options
ProtectHostname=true
LockPersonality=true
RestrictNamespaces=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM

# Save and restart
sudo systemctl daemon-reload
sudo systemctl restart health-check.service
```

## Application Security

### Rate Limiting

The application implements rate limiting:
- 10 requests per minute per IP
- Automatic cleanup of old entries
- HTTP 429 response when exceeded

Monitor rate limiting:

```bash
# Check for rate limit violations
sudo journalctl -u health-check-server | grep "Rate limit exceeded"

# Monitor frequent requesters
sudo journalctl -u health-check-server | jq -r '.ip' | sort | uniq -c | sort -nr | head -10
```

### Input Validation

The server includes:
- User-Agent sanitization
- Input length limits
- IP address validation
- Log injection prevention

### Security Headers

All responses include:
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block

Verify headers:

```bash
curl -I http://localhost:8001
```

## Monitoring and Detection

### Log Monitoring

```bash
# Monitor for suspicious activity
sudo journalctl -u health-check-server -f

# Filter by IP
sudo journalctl -u health-check-server | jq 'select(.ip == "192.168.1.100")'

# Monitor response times
sudo journalctl -u health-check-server | jq 'select(.response_time_ms | tonumber > 100)'

# Export logs for analysis
sudo journalctl -u health-check-server --output json > security-analysis.json
```

### Automated Monitoring Script

Create `/usr/local/bin/monitor-health-check.sh`:

```bash
#!/bin/bash

# Health Check Server Security Monitor

# Check service status
if ! systemctl is-active --quiet health-check-server; then
    echo "ALERT: Health check service is not running"
    exit 1
fi

# Check for rate limit violations (last hour)
RATE_LIMIT_VIOLATIONS=$(journalctl -u health-check-server --since "1 hour ago" | grep -c "Rate limit exceeded")
if [ "$RATE_LIMIT_VIOLATIONS" -gt 10 ]; then
    echo "ALERT: High rate of limit violations: $RATE_LIMIT_VIOLATIONS"
fi

# Check for unique IPs (last hour)
UNIQUE_IPS=$(journalctl -u health-check-server --since "1 hour ago" | jq -r '.ip' 2>/dev/null | sort -u | wc -l)
if [ "$UNIQUE_IPS" -gt 100 ]; then
    echo "ALERT: High number of unique IPs: $UNIQUE_IPS"
fi

# Check response times
HIGH_RESPONSE_TIMES=$(journalctl -u health-check-server --since "1 hour ago" | jq 'select(.response_time_ms | tonumber > 100)' 2>/dev/null | wc -l)
if [ "$HIGH_RESPONSE_TIMES" -gt 5 ]; then
    echo "ALERT: High response times detected: $HIGH_RESPONSE_TIMES"
fi

echo "Security monitoring completed"
```

Make it executable and add to cron:

```bash
sudo chmod +x /usr/local/bin/monitor-health-check.sh

# Add to crontab for every 5 minutes
sudo crontab -e
# Add: */5 * * * * /usr/local/bin/monitor-health-check.sh
```

## Intrusion Detection

### Fail2ban Integration

Create `/etc/fail2ban/jail.local`:

```ini
[health-check-server]
enabled = true
port = 8001
filter = health-check-server
logpath = /var/log/journal/*/system.journal
maxretry = 20
findtime = 3600
bantime = 3600
```

Create `/etc/fail2ban/filter.d/health-check-server.conf`:

```ini
[Definition]
failregex = .*"ip":"<HOST>".*"Rate limit exceeded".*
ignoreregex =
```

Restart fail2ban:

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status health-check-server
```

## Security Updates

### System Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Check for security updates only
sudo apt list --upgradable 2>/dev/null | grep -i security

# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### Application Updates

```bash
# Create update script
cat > update-health-check.sh << 'EOF'
#!/bin/bash
set -e

echo "Updating health check server..."

# Backup current binary
sudo cp /usr/local/bin/health-check-server /usr/local/bin/health-check-server.backup

# Stop service
sudo systemctl stop health-check-server

# Replace binary
sudo cp health-check-server /usr/local/bin/health-check-server
sudo chmod +x /usr/local/bin/health-check-server

# Start service
sudo systemctl start health-check-server

# Verify
sleep 2
if systemctl is-active --quiet health-check-server; then
    echo "Update successful"
    sudo rm /usr/local/bin/health-check-server.backup
else
    echo "Update failed, restoring backup"
    sudo systemctl stop health-check-server
    sudo cp /usr/local/bin/health-check-server.backup /usr/local/bin/health-check-server
    sudo systemctl start health-check-server
    exit 1
fi
EOF

chmod +x update-health-check.sh
```

## Incident Response

### Security Incident Checklist

1. **Detection**
   - Monitor logs for unusual patterns
   - Check service status
   - Review system performance

2. **Containment**
   - Block suspicious IPs
   - Increase rate limiting
   - Temporarily disable service if needed

3. **Investigation**
   - Export logs for analysis
   - Check system integrity
   - Review access logs

4. **Recovery**
   - Restore from backup if needed
   - Update security rules
   - Monitor for recurrence

### Emergency Commands

```bash
# Stop service immediately
sudo systemctl stop health-check-server

# Block specific IP
sudo iptables -A INPUT -s 192.168.1.100 -j DROP

# View recent activity
sudo journalctl -u health-check-server --since "1 hour ago"

# Check system integrity
sudo debsums -c

# Export all logs
sudo journalctl --output json > incident-logs.json
```

## Compliance

### Security Audit Checklist

- [ ] Service runs as non-privileged user
- [ ] File permissions are properly set
- [ ] Firewall rules are configured
- [ ] Rate limiting is enabled
- [ ] Security headers are present
- [ ] Logs are monitored
- [ ] System updates are applied
- [ ] Backup procedures are in place
- [ ] Incident response plan exists
- [ ] Security monitoring is active

### Regular Security Tasks

```bash
# Weekly security review
echo "=== Weekly Security Review ==="
echo "Service status:"
systemctl is-active health-check-server
echo "Recent rate limit violations:"
journalctl -u health-check-server --since "1 week ago" | grep "Rate limit exceeded" | wc -l
echo "Top requesting IPs:"
journalctl -u health-check-server --since "1 week ago" | jq -r '.ip' 2>/dev/null | sort | uniq -c | sort -nr | head -5
echo "Security updates available:"
apt list --upgradable 2>/dev/null | grep -i security | wc -l
```

## Additional Resources

- [Ubuntu Security Guide](https://ubuntu.com/security)
- [systemd Security Hardening](https://www.freedesktop.org/software/systemd/man/systemd.exec.html)
- [Go Security Best Practices](https://golang.org/doc/security)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)