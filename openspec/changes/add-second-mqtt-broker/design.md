## Context

The health-check-server currently supports a single MQTT broker for gate control. A new requirement has emerged to support a second MQTT broker for controlling a WebRadio2 device with volume control commands (vol+, vol-). This requires extending the architecture to support multiple independent MQTT connections simultaneously.

### Constraints
- Must maintain backward compatibility with existing single MQTT broker configuration
- Second broker is optional - system should work without it
- Both brokers must operate independently - failure of one should not affect the other
- Configuration file must support both brokers with separate credentials

### Stakeholders
- IoT system operators managing both gate control and WebRadio2
- System administrators deploying and configuring the service
- Monitoring systems consuming health check endpoints

## Goals / Non-Goals

### Goals
- Add support for a second MQTT broker with separate connection settings
- Create new `/action` endpoint for WebRadio2 control (vol+, vol-)
- Publish to fixed topic `Home/WebRadio2/Action` on second broker
- Maintain existing `/mqtt` endpoint functionality unchanged
- Ensure graceful degradation when second broker is unavailable

### Non-Goals
- Dynamic broker discovery or configuration
- Support for more than two brokers (can be extended later if needed)
- Subscription to MQTT topics (publish-only)
- Complex routing or transformation logic

## Decisions

### Decision 1: Independent MQTT Clients
**What:** Create two separate MQTT client instances instead of a single multiplexed client.

**Why:**
- Simpler implementation and debugging
- Clear separation of concerns between gate control and WebRadio2
- Independent error handling and reconnection logic
- Easier to test and maintain

**Alternatives considered:**
- Single client with multiple broker connections: More complex, harder to manage independently
- Dynamic client pool: Over-engineering for just two brokers

### Decision 2: Separate Configuration Sections
**What:** Use separate configuration sections for each broker (mqtt and mqtt2).

**Why:**
- Clear separation in config file
- Easy to understand which settings apply to which broker
- Backward compatible - existing configs work without modification
- Optional second broker - system works if mqtt2 section is missing

**Alternatives considered:**
- Array-based configuration: More complex parsing, less clear
- Single broker with multiple topics: Doesn't support separate brokers

### Decision 3: New Endpoint `/action` for WebRadio2
**What:** Create separate `/action` endpoint instead of extending `/mqtt`.

**Why:**
- Clear semantic separation: `/mqtt` for gate control, `/action` for WebRadio2
- Different parameter names (gate vs action) reflect different domains
- Easier to understand and use
- Independent rate limiting and logging

**Alternatives considered:**
- Extend `/mqtt` with additional parameters: Confusing, mixing concerns
- Single endpoint with type parameter: More complex validation logic

### Decision 4: Fixed Topic for WebRadio2
**What:** Use fixed topic `Home/WebRadio2/Action` instead of configurable.

**Why:**
- Simpler configuration
- WebRadio2 integration is specific and unlikely to change
- Reduces configuration errors
- Matches the specific use case described

**Alternatives considered:**
- Configurable topic: More flexible but adds complexity

### Decision 5: Optional Second Broker
**What:** System should work normally if second broker configuration is missing or invalid.

**Why:**
- Backward compatibility - existing deployments continue working
- Graceful degradation - system doesn't fail if second broker is unavailable
- Easier deployment and testing
- Clear error logging for operators

**Alternatives considered:**
- Required second broker: Breaking change, harder deployment

## Risks / Trade-offs

### Risks
1. **Configuration complexity** - Users must understand two separate broker configurations
   - **Mitigation:** Clear documentation, example config files, validation errors

2. **Connection overhead** - Two MQTT connections consume more resources
   - **Mitigation:** Minimal impact (two lightweight connections), monitor memory usage

3. **Error handling complexity** - Need to handle failures on two independent brokers
   - **Mitigation:** Independent error handling, clear logging, graceful degradation

4. **Testing complexity** - Need to test both brokers independently and together
   - **Mitigation:** Comprehensive test plan, integration tests

### Trade-offs
- **Simplicity vs Flexibility:** Fixed topic for WebRadio2 is simpler but less flexible
  - **Decision:** Favor simplicity for this specific use case

- **Independence vs Code reuse:** Separate clients have duplicated code
  - **Decision:** Favor independence for clarity and maintainability

- **Optional vs Required:** Optional second broker adds conditional logic
  - **Decision:** Favor optional for backward compatibility

## Migration Plan

### Steps
1. **Configuration update** - Add mqtt2 section to config.yaml (optional)
2. **Code deployment** - Deploy new version with second broker support
3. **Testing** - Verify existing functionality works unchanged
4. **Second broker setup** - Configure mqtt2 section when ready
5. **Verification** - Test `/action` endpoint with second broker

### Rollback
- Remove mqtt2 section from config.yaml
- Previous version of code will ignore missing mqtt2 section
- System continues with single broker operation

### Data Migration
- No data migration required
- Existing configurations work without modification

## Open Questions

None - requirements are clear and specific.

## Implementation Notes

### Configuration Structure
```yaml
mqtt:
  broker: "tcp://broker1.example.com:1883"
  client_id: "health-check-server"
  username: "user1"
  password: "pass1"

mqtt2:
  broker: "tcp://broker2.example.com:1883"
  client_id: "health-check-server-webradio"
  username: "user2"
  password: "pass2"
```

### HTTP Endpoints
- Existing: `GET /mqtt?gate=gate1` → Publish to first broker
- New: `GET /action?action=vol+` → Publish "vol+" to second broker topic `Home/WebRadio2/Action`
- New: `GET /action?action=vol-` → Publish "vol-" to second broker topic `Home/WebRadio2/Action`

### Error Handling
- Second broker failures logged but don't affect HTTP responses
- Independent reconnection logic for each broker
- Rate limiting applies separately to each endpoint
