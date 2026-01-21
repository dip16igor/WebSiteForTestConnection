## 1. Configuration Setup
- [ ] 1.1 Extend config.yaml file structure for second MQTT broker settings
- [ ] 1.2 Add second MQTT configuration struct in Go code
- [ ] 1.3 Update configuration file loading to include second broker settings
- [ ] 1.4 Add config file validation for second broker (required fields, valid values)

## 2. Second MQTT Client Integration
- [ ] 2.1 Implement second MQTT client initialization with separate credentials
- [ ] 2.2 Add connection logic for second broker with retry mechanism
- [ ] 2.3 Implement disconnect and cleanup logic for second broker
- [ ] 2.4 Add connection status monitoring for second broker
- [ ] 2.5 Ensure independent operation from first broker

## 3. Action Endpoint Implementation
- [ ] 3.1 Create new `/action` HTTP endpoint handler
- [ ] 3.2 Implement query parameter parsing for action value (vol+, vol-)
- [ ] 3.3 Add input validation for action parameter
- [ ] 3.4 Implement rate limiting for `/action` endpoint
- [ ] 3.5 Add security headers to `/action` responses
- [ ] 3.6 Add request logging with action details

## 4. Second MQTT Publish Logic
- [ ] 4.1 Implement message publishing to second MQTT broker
- [ ] 4.2 Publish to fixed topic `Home/WebRadio2/Action`
- [ ] 4.3 Map action values (vol+, vol-) to payloads
- [ ] 4.4 Add error handling for publish failures on second broker
- [ ] 4.5 Implement logging for successful publishes to second broker
- [ ] 4.6 Add logging for publish failures on second broker
- [ ] 4.7 Handle second broker connection errors gracefully

## 5. Error Handling
- [ ] 5.1 Implement graceful handling of second MQTT broker unavailability
- [ ] 5.2 Add authentication error handling for second broker
- [ ] 5.3 Implement connection retry logic for second broker
- [ ] 5.4 Add appropriate HTTP status codes for different error scenarios
- [ ] 5.5 Ensure existing endpoints remain functional during second broker errors

## 6. Logging Enhancement
- [ ] 6.1 Add structured logging for second broker operations
- [ ] 6.2 Log second broker connection status changes
- [ ] 6.3 Log publish operations with topic and payload for second broker
- [ ] 6.4 Log second broker errors with context
- [ ] 6.5 Add performance metrics logging for second broker

## 7. Testing
- [ ] 7.1 Write unit tests for configuration loading with second broker
- [ ] 7.2 Write unit tests for second MQTT client operations
- [ ] 7.3 Write unit tests for action parameter validation
- [ ] 7.4 Write integration tests for `/action` endpoint
- [ ] 7.5 Test error scenarios (second broker down, auth failure)
- [ ] 7.6 Test rate limiting on `/action` endpoint
- [ ] 7.7 Test simultaneous operation of both brokers

## 8. Documentation
- [ ] 8.1 Update README.md with second MQTT broker configuration instructions
- [ ] 8.2 Update example config.yaml file with second broker settings
- [ ] 8.3 Document `/action` endpoint usage with examples
- [ ] 8.4 Update deployment guide with second broker setup steps
- [ ] 8.5 Add troubleshooting section for second broker issues

## 9. Deployment
- [ ] 9.1 Update systemd service file if needed
- [ ] 9.2 Add second broker config to deployment scripts
- [ ] 9.3 Update firewall rules if second MQTT requires external access
- [ ] 9.4 Test deployment in staging environment
- [ ] 9.5 Verify production deployment
