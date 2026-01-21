## 1. Configuration Setup
- [x] 1.1 Create config.yaml file structure for MQTT settings
- [x] 1.2 Add MQTT configuration struct in Go code
- [x] 1.3 Implement configuration file loading with error handling
- [x] 1.4 Add config file validation (required fields, valid values)

## 2. MQTT Client Integration
- [x] 2.1 Add Eclipse Paho MQTT Go library dependency to go.mod
- [x] 2.2 Implement MQTT client initialization with credentials
- [x] 2.3 Add connection logic with retry mechanism
- [x] 2.4 Implement disconnect and cleanup logic
- [x] 2.5 Add connection status monitoring

## 3. Topic Mapping Logic
- [x] 3.1 Create topic mapping configuration structure
- [x] 3.2 Implement gate value to topic mapping function
- [x] 3.3 Add validation for gate values (gate1, gate2)
- [x] 3.4 Add support for configurable topic names

## 4. HTTP Endpoint Implementation
- [x] 4.1 Create new `/mqtt` HTTP endpoint handler
- [x] 4.2 Implement query parameter parsing for gate value
- [x] 4.3 Add input validation for query parameter
- [x] 4.4 Implement rate limiting for `/mqtt` endpoint
- [x] 4.5 Add security headers to `/mqtt` responses
- [x] 4.6 Add request logging with MQTT operation details

## 5. MQTT Publish Logic
- [x] 5.1 Implement message publishing to MQTT broker
- [x] 5.2 Add error handling for publish failures
- [x] 5.3 Implement logging for successful publishes
- [x] 5.4 Add logging for publish failures
- [x] 5.5 Handle MQTT connection errors gracefully

## 6. Error Handling
- [x] 6.1 Implement graceful handling of MQTT broker unavailability
- [x] 6.2 Add authentication error handling
- [x] 6.3 Implement connection retry logic
- [x] 6.4 Add appropriate HTTP status codes for different error scenarios
- [x] 6.5 Ensure health check endpoint remains functional during MQTT errors

## 7. Logging Enhancement
- [x] 7.1 Add structured logging for MQTT operations
- [x] 7.2 Log MQTT connection status changes
- [x] 7.3 Log publish operations with topic and payload
- [x] 7.4 Log MQTT errors with context
- [x] 7.5 Add performance metrics logging (publish time)

## 8. Testing
- [ ] 8.1 Write unit tests for configuration loading
- [ ] 8.2 Write unit tests for MQTT client operations
- [ ] 8.3 Write unit tests for topic mapping logic
- [ ] 8.4 Write integration tests for `/mqtt` endpoint
- [ ] 8.5 Test error scenarios (broker down, auth failure)
- [ ] 8.6 Test rate limiting on `/mqtt` endpoint
- [ ] 8.7 Load testing for MQTT publish operations

## 9. Documentation
- [ ] 9.1 Update README.md with MQTT configuration instructions
- [x] 9.2 Add example config.yaml file
- [ ] 9.3 Document MQTT endpoint usage with examples
- [ ] 9.4 Update deployment guide with MQTT setup steps
- [ ] 9.5 Add troubleshooting section for MQTT issues

## 10. Deployment
- [ ] 10.1 Update systemd service file if needed
- [ ] 10.2 Add config file to deployment scripts
- [ ] 10.3 Update firewall rules if MQTT requires external access
- [ ] 10.4 Test deployment in staging environment
- [x] 10.5 Verify production deployment
