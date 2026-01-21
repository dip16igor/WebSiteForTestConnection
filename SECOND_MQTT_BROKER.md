# Second MQTT Broker Support

The health-check-server now supports an optional second MQTT broker for independent systems (e.g., WebRadio2 control).

## Overview

- **Optional Configuration**: The second broker is completely optional - the server works normally without it
- **Independent Operation**: Both brokers operate independently - failure of one doesn't affect the other
- **Separate Endpoints**: Each broker has its own HTTP endpoint
- **Graceful Degradation**: System continues working if second broker is unavailable

## Configuration

Add the `mqtt2` section to your `config.yaml`:

```yaml
mqtt2:
  # MQTT broker address (tcp://hostname:port)
  broker: "tcp://your-second-broker.example.com:1883"
  
  # MQTT client ID (must be unique)
  client_id: "health-check-server-webradio"
  
  # Authentication credentials (optional)
  username: "your_second_username"
  password: "your_second_password"
  
  # Quality of Service level (0, 1, or 2)
  qos: 1
  
  # Whether to retain messages on the broker
  retain: false
  
  # Connection timeout in seconds
  connect_timeout: 10
```

### Configuration Notes

- The `mqtt2` section is **optional** - remove it if not needed
- All fields in `mqtt2` are the same as in `mqtt` section
- If `mqtt2` is configured, the server will attempt to connect on startup
- If connection fails, the server logs an error but continues running
- No `gates` configuration needed for `mqtt2` - uses fixed topic

## HTTP Endpoint: `/action`

When the second MQTT broker is configured, a new HTTP endpoint `/action` becomes available.

### Usage

```bash
# Volume up
curl "http://localhost:8001/action?action=vol+"

# Volume down
curl "http://localhost:8001/action?action=vol-"
```

### Behavior

The `/action` endpoint:
1. Validates the `action` query parameter (must be "vol+" or "vol-")
2. Publishes the action value to the fixed topic `Home/WebRadio2/Action` on the second broker
3. Responds with HTTP 200 OK

### Valid Actions

- `vol+` - Volume up command
- `vol-` - Volume down command

Any other value will result in HTTP 400 Bad Request.

## Rate Limiting

Both MQTT endpoints have independent rate limiting:
- `/mqtt` endpoint: 10 requests per minute per IP
- `/action` endpoint: 10 requests per minute per IP

Rate limit violations are logged separately for each endpoint.

## Logging

### Second Broker Connection Logs

```json
{
  "timestamp": "2026-01-21T03:00:00Z",
  "level": "info",
  "message": "Second MQTT broker connected",
  "broker": "tcp://your-second-broker.example.com:1883"
}
```

### Action Publish Logs

```json
{
  "timestamp": "2026-01-21T03:00:00Z",
  "level": "info",
  "message": "Action publish: Attempting to publish",
  "ip": "192.168.1.100",
  "action": "vol+",
  "topic": "Home/WebRadio2/Action"
}
```

```json
{
  "timestamp": "2026-01-21T03:00:00Z",
  "level": "info",
  "message": "Action message published",
  "ip": "192.168.1.100",
  "action": "vol+",
  "topic": "Home/WebRadio2/Action",
  "response_time_ms": "5"
}
```

### Error Logs

```json
{
  "timestamp": "2026-01-21T03:00:00Z",
  "level": "error",
  "message": "Failed to connect to second MQTT broker",
  "error": "connection refused"
}
```

```json
{
  "timestamp": "2026-01-21T03:00:00Z",
  "level": "error",
  "message": "Action publish: Failed to publish message",
  "ip": "192.168.1.100",
  "action": "vol+",
  "topic": "Home/WebRadio2/Action",
  "error": "connection lost"
}
```

## Troubleshooting

### Second Broker Not Connecting

```bash
# Check logs for connection errors
sudo journalctl -u health-check-server | grep "second MQTT"

# Verify broker is reachable
telnet your-second-broker.example.com 1883

# Test MQTT credentials manually
mosquitto_pub -h your-second-broker.example.com -t "test" -m "test" \
  -u your_second_username -P your_second_password
```

### Invalid Action Parameter

```bash
# Check logs for validation errors
sudo journalctl -u health-check-server | grep "Invalid action value"

# Ensure query parameter is correctly formatted
curl "http://localhost:8001/action?action=vol+"
```

### Second Broker Not Configured

If you see "second MQTT broker not configured" in logs:

1. Check if `mqtt2` section exists in `config.yaml`
2. Verify all required fields are present (`broker`, `client_id`)
3. Restart the service after configuration changes

```bash
# Check config file
sudo cat /etc/health-check-server/config.yaml

# Restart service
sudo systemctl restart health-check-server
```

## Security Considerations

- Second broker credentials are stored in `config.yaml` with same security as first broker
- File permissions should be 600 (read/write for owner only)
- Both brokers have independent rate limiting
- All operations on both brokers are logged
- Second broker is optional - no security impact if not configured

## Migration from Single Broker

If you're migrating from a single broker setup:

1. Your existing `mqtt` configuration remains unchanged
2. Add the optional `mqtt2` section when ready
3. Restart the service
4. Test the new `/action` endpoint
5. Both endpoints will work simultaneously

No changes required to existing `/mqtt` endpoint or gate control functionality.
