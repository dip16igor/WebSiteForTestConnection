# Step-by-Step Deployment Guide

This guide provides detailed instructions for deploying the health check server on your Ubuntu VPS.

## Prerequisites

- Ubuntu 20.04+ VPS
- sudo access
- Internet connection

## Step 1: Upload Files to VPS

From your local machine, upload the required files to the VPS:

```bash
# Replace with your VPS details
scp *.sh *.go *.service *.md user@your-vps:/tmp/
```

## Step 2: Connect to VPS

```bash
ssh user@your-vps
cd /tmp
```

## Step 3: Make Scripts Executable

```bash
# Make deployment and test scripts executable
sudo chmod +x deploy.sh
sudo chmod +x test.sh

# Verify permissions
ls -la *.sh
```

## Step 4: Run Deployment Script

```bash
# Option 1: Run directly with bash
sudo bash deploy.sh

# Option 2: Run as executable (after chmod +x)
sudo ./deploy.sh
```

## Step 5: Verify Deployment

```bash
# Test the health endpoint
curl http://localhost:8001

# Check service status
sudo systemctl status health-check-server

# View recent logs
sudo journalctl -u health-check-server -n 10
```

## Step 6: Run Comprehensive Tests

```bash
# Run the test suite
./test.sh

# Or with sudo if needed
sudo ./test.sh
```

## Troubleshooting Common Issues

### Issue 1: "command not found" for deploy.sh

**Solution**: Make the script executable first:
```bash
sudo chmod +x deploy.sh
sudo ./deploy.sh
```

### Issue 2: Go installation fails

**Solution**: Install Go manually:
```bash
# Download Go
wget https://golang.org/dl/go1.21.5.linux-amd64.tar.gz

# Extract to /usr/local
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz

# Add to PATH
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Verify installation
/usr/local/go/bin/go version
```

### Issue 3: Service fails to start

**Solution**: Check logs and permissions:
```bash
# Check service logs
sudo journalctl -u health-check-server -n 20

# Check binary permissions
ls -la /usr/local/bin/health-check-server

# Check user exists
id healthcheck
```

### Issue 4: Port 8001 blocked

**Solution**: Configure firewall:
```bash
# Using ufw
sudo ufw allow 8001/tcp

# Using iptables
sudo iptables -A INPUT -p tcp --dport 8001 -j ACCEPT

# Check if port is open
sudo netstat -tlnp | grep :8001
```

### Issue 5: Rate limiting not working

**Solution**: Check if requests are coming from different IPs:
```bash
# Monitor logs
sudo journalctl -u health-check-server -f

# Test rate limiting manually
for i in {1..12}; do curl -s http://localhost:8001; done
```

## Manual Deployment Steps

If the automated script fails, here are the manual steps:

### 1. Install Go

```bash
# Download and install Go
wget -q https://golang.org/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
```

### 2. Create User

```bash
sudo useradd -r -s /bin/false -d /var/lib/healthcheck -M healthcheck
```

### 3. Create Directories

```bash
sudo mkdir -p /var/lib/healthcheck
sudo mkdir -p /var/log/health-check-server
sudo chown healthcheck:healthcheck /var/lib/healthcheck
sudo chown healthcheck:healthcheck /var/log/health-check-server
```

### 4. Build Application

```bash
/usr/local/go/bin/go build -o /usr/local/bin/health-check-server main.go
sudo chown root:healthcheck /usr/local/bin/health-check-server
sudo chmod 750 /usr/local/bin/health-check-server
```

### 5. Install Service

```bash
sudo cp health-check.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable health-check.service
```

### 6. Configure Firewall

```bash
sudo ufw allow 8001/tcp
```

### 7. Start Service

```bash
sudo systemctl start health-check.service
```

## Verification Commands

```bash
# Check if service is running
sudo systemctl is-active health-check-server

# Test HTTP endpoint
curl -v http://localhost:8001

# Check logs
sudo journalctl -u health-check-server -f

# Test rate limiting
for i in {1..12}; do curl -s -w "%{http_code}\n" http://localhost:8001; done
```

## Expected Output

When everything is working correctly:

1. **HTTP Request**: Should return "OK" with HTTP 200 status
2. **Service Status**: Should show "active (running)"
3. **Logs**: Should show JSON log entries with IP, user agent, and response time
4. **Rate Limiting**: 11th request should return HTTP 429

## Monitoring Setup

For ongoing monitoring, add these to your monitoring system:

```bash
# Service health check
systemctl is-active health-check-server

# HTTP endpoint check
curl -f --max-time 5 http://localhost:8001

# Log monitoring
journalctl -u health-check-server --since "1 hour ago" | grep -c "Rate limit exceeded"
```

## Support

If you encounter issues:

1. Check the service logs: `sudo journalctl -u health-check-server -f`
2. Review the troubleshooting section above
3. Run the test suite: `./test.sh`
