## Context
The health check server currently provides a simple HTTP 200 response endpoint. The requirement is to extend functionality to publish messages to an MQTT broker when receiving GET requests with specific JSON payload. This enables integration with IoT systems and external monitoring infrastructure.

## Goals / Non-Goals

### Goals
- Add MQTT publish capability without breaking existing health check functionality
- Maintain security and rate limiting principles
- Keep resource usage minimal (< 50MB memory)
- Ensure graceful degradation when MQTT broker is unavailable
- Support configurable MQTT broker connection settings
- Provide clear logging for debugging and monitoring

### Non-Goals
- MQTT subscription functionality (only publish needed)
- Complex message routing or transformation
- MQTT message persistence or queuing
- WebSocket or other protocol support
- MQTT broker management or monitoring

## Decisions

### Decision 1: MQTT Library Selection
**Choice**: Eclipse Paho MQTT Go Client (`github.com/eclipse/paho.mqtt.golang`)

**Rationale**:
- Well-maintained, mature library with active community
- Supports MQTT 3.1.1 and 5.0 protocols
- Compatible with Mosquitto broker
- Minimal dependencies
- Good documentation and examples

**Alternatives considered**:
- `github.com/mochi-co/mqtt` - More feature-rich but heavier
- `github.com/256dpi/gomqtt` - Simpler but less mature
- Custom implementation - Too complex, reinventing the wheel

### Decision 2: Configuration File Format
**Choice**: YAML configuration file (`config.yaml`)

**Rationale**:
- Human-readable and easy to edit
- Standard format for Go applications
- Supports comments for documentation
- Easy to parse with `gopkg.in/yaml.v3`

**Configuration structure**:
```yaml
mqtt:
  broker: "tcp://192.168.1.100:1883"
  username: "user"
  password: "password"
  client_id: "health-check-server"
  qos: 1
  retain: false
  topics:
    gate1: "home/gate1/status"
    gate2: "home/gate2/status"
```

**Alternatives considered**:
- Environment variables - Less flexible for complex config
- JSON - Less readable, no comments
- TOML - Less common in Go ecosystem

### Decision 3: HTTP Endpoint Design
**Choice**: Separate `/mqtt` endpoint with GET method and query parameter

**Rationale**:
- Keeps existing `/` health check endpoint unchanged
- Clear separation of concerns
- GET method aligns with user requirement
- Query parameters are simple and straightforward for gate value

**Request format**:
```bash
curl -X GET "http://localhost:8001/mqtt?gate=gate1"
```

**Alternatives considered**:
- Extend existing `/` endpoint - Violates single responsibility
- POST method - User specifically requested GET
- JSON body - Unconventional for GET requests, harder to use

### Decision 4: MQTT Connection Management
**Choice**: Lazy connection with automatic reconnection

**Rationale**:
- Don't establish connection until first publish request
- Paho library handles automatic reconnection
- Reduces startup time and resource usage
- Graceful degradation if broker unavailable

**Connection strategy**:
1. Initialize MQTT client on startup
2. Connect on first publish request
3. Use Paho's auto-reconnect feature
4. Log connection status changes
5. Continue serving HTTP requests if MQTT fails

**Alternatives considered**:
- Connect on startup - Blocks startup if broker down
- Persistent connection pool - Overkill for simple use case
- No reconnection - Poor reliability

### Decision 5: Error Handling Strategy
**Choice**: Non-blocking error handling with logging

**Rationale**:
- HTTP health check endpoint must remain functional
- MQTT failures shouldn't crash the service
- Clear logging for debugging
- Appropriate HTTP status codes for different scenarios

**Error scenarios**:
- MQTT broker unavailable: Log error, return HTTP 200 (best effort)
- Authentication failure: Log error, return HTTP 500
- Invalid gate value: Log error, return HTTP 400
- Publish timeout: Log error, return HTTP 200 (async retry)

**Alternatives considered**:
- Retry with exponential backoff - Too complex for current needs
- Circuit breaker pattern - Overkill for single broker
- Fail-fast approach - Breaks health check functionality

### Decision 6: Security Considerations
**Choice**: Apply existing security patterns to MQTT endpoint

**Rationale**:
- Maintain consistency across endpoints
- Reuse rate limiting infrastructure
- Follow security-first approach

**Security measures**:
- Rate limiting: 10 requests per minute per IP (same as health check)
- Input validation: Strict JSON schema validation
- Security headers: Same as health check endpoint
- Config file permissions: 600 (owner read/write only)
- MQTT credentials: Stored in config file, not in code

**Alternatives considered**:
- Separate rate limiting for MQTT - Unnecessary complexity
- No rate limiting - Security risk
- Hardcoded credentials - Security violation

### Decision 7: Logging Strategy
**Choice**: Structured JSON logging with MQTT-specific fields

**Rationale**:
- Consistent with existing logging approach
- Easy integration with systemd journal
- Supports log aggregation and analysis
- Clear separation of MQTT and HTTP logs

**Log format**:
```json
{
  "timestamp": "2023-12-13T04:48:00Z",
  "level": "info",
  "message": "MQTT message published",
  "gate": "gate1",
  "topic": "home/gate1/status",
  "ip": "192.168.1.100",
  "response_time_ms": "5"
}
```

**Alternatives considered**:
- Separate log files - Harder to correlate events
- Less detailed logging - Harder to debug issues
- Plain text logs - Harder to parse and analyze

## Architecture

```mermaid
graph TD
    A[HTTP Client] --> B[/mqtt Endpoint]
    B --> C[Rate Limiter]
    B --> D[JSON Parser]
    D --> E[Gate Validator]
    E --> F[Topic Mapper]
    F --> G[MQTT Client]
    G --> H[MQTT Broker]
    B --> I[Logger]
    G --> I
    C --> I
```

### Component Responsibilities

1. **HTTP Handler**: Parse request, validate input, coordinate flow
2. **Rate Limiter**: Enforce request limits per IP
3. **JSON Parser**: Extract gate value from request body
4. **Gate Validator**: Ensure gate value is valid (gate1/gate2)
5. **Topic Mapper**: Map gate value to MQTT topic
6. **MQTT Client**: Manage connection and publish messages
7. **Logger**: Record all operations and errors

## Risks / Trade-offs

### Risk 1: MQTT Broker Downtime
**Impact**: MQTT publish operations fail during broker downtime
**Mitigation**:
- Non-blocking error handling
- Automatic reconnection via Paho library
- Continue serving HTTP health checks
- Clear logging for monitoring

### Risk 2: Memory Usage Increase
**Impact**: May exceed 50MB memory limit
**Mitigation**:
- Use Paho's lightweight client configuration
- Lazy connection (don't connect until needed)
- Monitor memory usage in testing
- Adjust Paho client buffers if needed

### Risk 3: Configuration File Exposure
**Impact**: MQTT credentials could be compromised
**Mitigation**:
- Set file permissions to 600
- Document security requirements
- Consider environment variables for production
- Add to .gitignore

### Trade-off 1: GET with Body vs POST
**Decision**: Use GET with JSON body (user requirement)
**Trade-off**: Unconventional but acceptable for this use case
**Rationale**: User specifically requested GET method

### Trade-off 2: Synchronous vs Asynchronous Publish
**Decision**: Synchronous publish with timeout
**Trade-off**: Slightly slower response time
**Rationale**: Simpler error handling, immediate feedback

## Migration Plan

### Phase 1: Development
1. Add Paho MQTT dependency to go.mod
2. Implement configuration loading
3. Create MQTT client wrapper
4. Implement `/mqtt` endpoint
5. Add comprehensive logging
6. Write unit and integration tests

### Phase 2: Testing
1. Test with local Mosquitto broker
2. Test error scenarios (broker down, auth failure)
3. Load test MQTT publish operations
4. Verify memory usage stays under 50MB
5. Test rate limiting on `/mqtt` endpoint

### Phase 3: Deployment
1. Create example config.yaml
2. Update deployment scripts
3. Update systemd service if needed
4. Deploy to staging environment
5. Monitor logs and performance
6. Deploy to production

### Rollback Plan
1. Revert to previous version of main.go
2. Remove config.yaml file
3. Restart systemd service
4. Verify health check endpoint works

## Open Questions

1. **Q**: Should we support additional gate values beyond gate1/gate2?
   **A**: Start with gate1/gate2 as specified, can extend later if needed

2. **Q**: What should be the MQTT message payload?
   **A**: For now, use gate value as payload. Can extend to include timestamp or other metadata later.

3. **Q**: Should we implement message queuing when broker is down?
   **A**: No, keep it simple. If broker is down, log error and continue.

4. **Q**: What QoS level should we use?
   **A**: QoS 1 (at least once) - good balance between reliability and performance

5. **Q**: Should we support MQTT 5.0 features?
   **A**: No, stick to MQTT 3.1.1 for broader compatibility with Mosquitto
