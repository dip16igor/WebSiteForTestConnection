# Health Check Server

A lightweight, secure web server for VPS health monitoring that responds with HTTP 200 status on port 8001.

## Features

- **Simple HTTP Endpoint**: Responds with HTTP 200 OK and "OK" body
- **Detailed Logging**: Logs IP addresses, user agents, and response times in structured JSON format
- **Security Hardened**: Rate limiting, security headers, input validation
- **Systemd Integration**: Runs as a systemd service with proper process management
- **Low Resource Usage**: Minimal memory footprint (< 50MB)

## Quick Start

### Prerequisites

- Ubuntu 20.04+ or compatible Linux distribution
- Go 1.19+ (for building)
- systemd (for service management)
- sudo access

### Building

```bash
# Clone or download the source files
# Build the binary
go build -o health-check-server main.go

# Or cross-compile for Ubuntu
GOOS=linux GOARCH=amd64 go build -o health-check-server main.go
```

### Installation

```bash
# Create dedicated user
sudo useradd -r -s /bin/false -d /var/lib/healthcheck healthcheck

# Create binary directory and copy binary
sudo mkdir -p /usr/local/bin
sudo cp health-check-server /usr/local/bin/
sudo chmod +x /usr/local/bin/health-check-server

# Install systemd service
sudo cp health-check.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable health-check.service

# Configure firewall (if using ufw)
sudo ufw allow 8001/tcp

# Start the service
sudo systemctl start health-check.service

# Check status
sudo systemctl status health-check.service
```

### Testing

```bash
# Test the health endpoint
curl http://localhost:8001

# Should return: OK

# Check logs
sudo journalctl -u health-check-server -f
```

## Configuration

The server runs with the following default configuration:

- **Port**: 8001
- **Rate Limiting**: 10 requests per minute per IP
- **Timeouts**: 
  - Read timeout: 10 seconds
  - Write timeout: 10 seconds
  - Idle timeout: 60 seconds
- **Security Headers**: 
  - X-Content-Type-Options: nosniff
  - X-Frame-Options: DENY
  - X-XSS-Protection: 1; mode=block

## Logging

The server outputs structured JSON logs to systemd journal:

```json
{
  "timestamp": "2023-12-13T04:48:00Z",
  "level": "info",
  "message": "Health check request processed",
  "ip": "192.168.1.100",
  "user_agent": "curl/7.68.0",
  "response_time_ms": "2"
}
```

### Viewing Logs

```bash
# View real-time logs
sudo journalctl -u health-check-server -f

# View recent logs
sudo journalctl -u health-check-server --since "1 hour ago"

# Filter by IP
sudo journalctl -u health-check-server | grep '"ip":"192.168.1.100"'

# Export logs to file
sudo journalctl -u health-check-server --output json > health-logs.json
```

## Security Features

### Rate Limiting
- 10 requests per minute per IP address
- Automatic cleanup of old rate limit entries
- HTTP 429 response when rate limit exceeded

### Input Validation
- User-Agent sanitization to prevent log injection
- Input length limits
- IP address validation

### Security Headers
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block

### Systemd Hardening
- Runs as non-privileged user
- Filesystem restrictions
- Network restrictions
- Resource limits

## Monitoring

### Health Monitoring

The server itself is the health check endpoint. Monitor it by:

```bash
# Simple health check
curl -f http://localhost:8001 || echo "Health check failed"

# With timeout
curl -f --max-time 5 http://localhost:8001 || echo "Health check failed"
```

### Service Monitoring

```bash
# Check service status
systemctl is-active health-check-server

# Check if service is enabled
systemctl is-enabled health-check-server

# Get service metrics
systemctl show health-check-server -p CPUUsageNSec -p MemoryCurrent
```

### Log Monitoring

Monitor logs for unusual patterns:

```bash
# Rate limit violations
sudo journalctl -u health-check-server | grep "Rate limit exceeded"

# Error messages
sudo journalctl -u health-check-server -p err

# High response times (>100ms)
sudo journalctl -u health-check-server | jq 'select(.response_time_ms | tonumber > 100)'
```

## Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   # Check service status
   sudo systemctl status health-check-server
   
   # Check logs for errors
   sudo journalctl -u health-check-server -p err
   ```

2. **Port already in use**
   ```bash
   # Check what's using port 8001
   sudo netstat -tlnp | grep :8001
   
   # Or with ss
   sudo ss -tlnp | grep :8001
   ```

3. **Permission denied**
   ```bash
   # Check binary permissions
   ls -la /usr/local/bin/health-check-server
   
   # Check user permissions
   id healthcheck
   ```

4. **Firewall blocking**
   ```bash
   # Check ufw status
   sudo ufw status
   
   # Check iptables rules
   sudo iptables -L -n | grep 8001
   ```

### Debug Mode

For debugging, you can run the server manually:

```bash
# Stop the service
sudo systemctl stop health-check-server

# Run manually
sudo -u healthcheck /usr/local/bin/health-check-server
```

## Maintenance

### Updates

```bash
# Stop service
sudo systemctl stop health-check-server

# Replace binary
sudo cp new-health-check-server /usr/local/bin/health-check-server
sudo chmod +x /usr/local/bin/health-check-server

# Start service
sudo systemctl start health-check-server

# Verify
sudo systemctl status health-check-server
```

### Log Rotation

Logs are handled by systemd journal. Configure retention in `/etc/systemd/journald.conf`:

```ini
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=100M
MaxRetentionSec=30day
```

Then restart journald:

```bash
sudo systemctl restart systemd-journald
```

## Performance

### Resource Usage

- **Memory**: < 50MB typical usage
- **CPU**: < 1% under normal load
- **Disk**: Minimal (logs only)

### Load Testing

```bash
# Install wrk for load testing
sudo apt-get install wrk

# Run load test (100 connections for 30 seconds)
wrk -t4 -c100 -d30s http://localhost:8001

# Monitor during test
sudo journalctl -u health-check-server -f
```

## License

[Add your license here]