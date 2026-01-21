# Health Check Server

A lightweight, secure web server for VPS health monitoring with MQTT integration. Responds with HTTP 200 status on port 8001 and can publish messages to MQTT broker.

## Features

- **Simple HTTP Endpoint**: Responds with HTTP 200 OK and "OK" body
- **MQTT Integration**: Publish messages to MQTT broker via HTTP endpoint
- **Detailed Logging**: Logs IP addresses, user agents, and response times in structured JSON format
- **Security Hardened**: Rate limiting, security headers, input validation
- **Systemd Integration**: Runs as a systemd service with proper process management
- **Low Resource Usage**: Minimal memory footprint (< 50MB)

## Quick Start

### Prerequisites

- Ubuntu 20.04+ or compatible Linux distribution
- Go 1.19+ (for building)
- systemd (for service management)
- MQTT broker (e.g., Mosquitto) for MQTT functionality
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

# Copy example config and customize
sudo cp config.example.yaml /etc/health-check-server/config.yaml
sudo chmod 600 /etc/health-check-server/config.yaml
sudo chown healthcheck:healthcheck /etc/health-check-server/config.yaml

# Edit config with your MQTT broker settings
sudo nano /etc/health-check-server/config.yaml

# Install systemd service
sudo cp health-check.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable health-check.service

# Configure firewall (if using ufw)
sudo ufw allow 8001/tcp

# Start service
sudo systemctl start health-check.service

# Check status
sudo systemctl status health-check.service
```

### Testing

```bash
# Test health endpoint
curl http://localhost:8001

# Should return: OK

# Test MQTT publish endpoint with query parameter
curl "http://localhost:8001/mqtt?gate=gate1"

# Should return: OK

# Test with gate2
curl "http://localhost:8001/mqtt?gate=gate2"

# Should return: OK

# Check logs
sudo journalctl -u health-check-server -f
```

## MQTT Configuration

The server requires a `config.yaml` file for MQTT broker settings. Copy `config.example.yaml` and customize it:

```yaml
mqtt:
  broker: "tcp://192.168.1.100:1883"
  client_id: "health-check-server"
  username: "your_username"
  password: "your_password"
  qos: 1
  retain: false
  connect_timeout: 10
  gates:
    gate1:
      topic: "home/gates/gate1"
      payload: "123456"
    gate2:
      topic: "home2/gates/gate"
      payload: "37462ацуа767"
```

Each gate configuration includes:
- `topic`: The MQTT topic to publish to
- `payload`: The message payload to send (can be any string value)

### MQTT Endpoint Usage

Send GET requests to `/mqtt` endpoint with query parameter:

```bash
# Publish for gate1
curl "http://localhost:8001/mqtt?gate=gate1"

# Publish for gate2
curl "http://localhost:8001/mqtt?gate=gate2"
```

The server will:
1. Validate query parameter (gate value must be "gate1" or "gate2")
2. Map gate value to configured MQTT topic and payload
3. Publish the configured payload to the MQTT topic
4. Respond with HTTP 200 OK

Note: The payload is configurable in `config.yaml` for each gate, not sent in the HTTP request.

### MQTT Security

- Configuration file should have restricted permissions (600)
- MQTT credentials are stored in config file, not in code
- Rate limiting applies to MQTT endpoint (10 requests/minute per IP)
- All MQTT operations are logged

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

### Health Check Log Entry

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

### MQTT Publish Log Entry

```json
{
  "timestamp": "2023-12-13T04:48:00Z",
  "level": "info",
  "message": "MQTT message published",
  "ip": "192.168.1.100",
  "gate": "gate1",
  "topic": "home/gates/gate1",
  "payload": "123456",
  "response_time_ms": "5"
}
```

### MQTT Connection Log Entry

```json
{
  "timestamp": "2023-12-13T04:48:00Z",
  "level": "info",
  "message": "MQTT client connected",
  "broker": "tcp://192.168.1.100:1883"
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

# Filter by MQTT operations
sudo journalctl -u health-check-server | grep "MQTT"

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
- Query parameter validation for MQTT endpoint

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

# MQTT publish failures
sudo journalctl -u health-check-server | grep "Failed to publish"
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

5. **MQTT connection failed**
   ```bash
   # Check MQTT broker is running
   sudo systemctl status mosquitto

   # Test MQTT broker connectivity
   mosquitto_sub -h 192.168.1.100 -t "#" -u username -P password

   # Check config file exists and is readable
   ls -la /etc/health-check-server/config.yaml

   # Verify config file syntax
   sudo -u healthcheck cat /etc/health-check-server/config.yaml
   ```

6. **MQTT authentication error**
   ```bash
   # Verify credentials in config.yaml
   sudo cat /etc/health-check-server/config.yaml

   # Test MQTT credentials manually
   mosquitto_pub -h 192.168.1.100 -t "test" -m "test" \
     -u username -P password
   ```

7. **Invalid gate value error**
    ```bash
    # Check logs for validation errors
    sudo journalctl -u health-check-server | grep "Invalid gate value"

    # Ensure query parameter is correctly formatted
    curl "http://localhost:8001/mqtt?gate=gate1"
    ```

8. **Configuration file errors**
   ```bash
   # Check for missing required fields
   sudo journalctl -u health-check-server -p err | grep "required"

   # Verify config file structure
   cat /etc/health-check-server/config.yaml

   # Check file permissions
   ls -la /etc/health-check-server/config.yaml
   ```

### Debug Mode

For debugging, you can run the server manually:

```bash
# Stop the service
sudo systemctl stop health-check-server

# Run manually with config file
sudo -u healthcheck /usr/local/bin/health-check-server

# Or run from source directory
cd /path/to/health-check-server
go run main.go
```

### MQTT Debugging

```bash
# Subscribe to all topics to see messages
mosquitto_sub -h 192.168.1.100 -t "#" -u username -P password

# Subscribe to specific topic
mosquitto_sub -h 192.168.1.100 -t "home/gates/gate1" -u username -P password

# Check MQTT broker logs
sudo journalctl -u mosquitto -f
```

## Maintenance

### Updates

```bash
# Stop the service
sudo systemctl stop health-check-server

# Replace the binary
sudo cp new-health-check-server /usr/local/bin/health-check-server
sudo chmod +x /usr/local/bin/health-check-server

# Start the service
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

### MQTT Performance

- Connection: Lazy initialization (connects on first publish)
- Reconnection: Automatic with 30-second max interval
- QoS: Configurable (default QoS 1 for at-least-once delivery)
- Publish timeout: 10 seconds default

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
