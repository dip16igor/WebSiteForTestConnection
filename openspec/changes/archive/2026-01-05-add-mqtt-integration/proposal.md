# Change: Add MQTT Integration

## Status
**✅ IMPLEMENTED** - Deployed to production (109.69.19.36:8001)

## Why
Add capability to publish messages to MQTT broker for integration with IoT systems and external monitoring. This enables the health check server to act as a gateway for triggering events in MQTT-based systems.

## What Changes
- Add new HTTP endpoint `/mqtt` that accepts GET requests with query parameter `gate`
- Implement MQTT client integration using Eclipse Paho MQTT Go library
- Add configuration file for MQTT broker settings (broker URL, port, username, password)
- Add topic mapping logic based on gate value (gate1/gate2 → different MQTT topics)
- Maintain existing `/` health check endpoint functionality
- Add logging for MQTT publish operations and errors

## Impact
- Affected specs: health-check-server (new capability added)
- Affected code: main.go (new endpoint, MQTT client, configuration loading)
- New dependencies: Eclipse Paho MQTT Go library
- New configuration file: config.yaml for MQTT settings
- External dependency: MQTT broker (Mosquitto) connectivity required

## Implementation Details
- MQTT client connects to broker on startup
- GET `/mqtt?gate=gate1` publishes "179226315200" to "GateControl/Gate"
- GET `/mqtt?gate=gate2` publishes "279226315200" to "GateControl/Gate"
- Automatic reconnection on connection loss
- Rate limiting: 10 requests per minute per IP
- Structured JSON logging to systemd journal
