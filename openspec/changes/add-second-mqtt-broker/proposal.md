# Change: Add Second MQTT Broker Support

## Why
Add capability to publish messages to a second MQTT broker with separate authentication credentials. This enables the health check server to support multiple MQTT systems simultaneously, such as controlling both a gate system and a WebRadio2 device from different brokers.

## What Changes
- Add configuration for a second MQTT broker (separate address, username, password)
- Extend MQTT client to support two independent broker connections
- Add new HTTP endpoint `/action` that accepts GET requests with query parameter `action` (vol+, vol-)
- Publish action values to topic `Home/WebRadio2/Action` on the second MQTT broker
- Maintain existing `/mqtt` endpoint functionality for the first broker
- Add logging for second broker operations

## Impact
- Affected specs: health-check-server (new capability added)
- Affected code: main.go (new endpoint, second MQTT client, extended configuration)
- New configuration fields: second MQTT broker settings in config.yaml
- External dependency: Second MQTT broker connectivity required
