# health-check-server Specification

## Purpose
The health-check-server provides HTTP health check endpoints and MQTT integration for IoT systems. It responds to health check requests and publishes messages to an MQTT broker based on gate values, enabling integration with external monitoring and control systems.

## Requirements
### Requirement: HTTP Health Check Endpoint
The system SHALL provide an HTTP endpoint that responds with status 200 OK on port 8001.

#### Scenario: Successful health check
- **WHEN** a GET request is made to the root endpoint
- **THEN** the system SHALL respond with HTTP 200 status
- **AND** the response SHALL contain "OK" as the body

### Requirement: Detailed Request Logging
The system SHALL log detailed information about each incoming request for monitoring and security purposes.

#### Scenario: Request logging
- **WHEN** any HTTP request is received
- **THEN** the system SHALL log the client IP address
- **AND** the system SHALL log the User-Agent header
- **AND** the system SHALL log the response time in milliseconds
- **AND** the system SHALL log the timestamp in ISO 8601 format

### Requirement: Security Headers
The system SHALL include security headers in all responses to prevent common web vulnerabilities.

#### Scenario: Security headers in response
- **WHEN** any HTTP response is sent
- **THEN** the system SHALL include X-Content-Type-Options: nosniff header
- **AND** the system SHALL include X-Frame-Options: DENY header
- **AND** the system SHALL include X-XSS-Protection: 1; mode=block header

### Requirement: Rate Limiting
The system SHALL implement rate limiting to prevent abuse and denial of service attacks.

#### Scenario: Rate limiting enforcement
- **WHEN** more than 10 requests are received from the same IP within 1 minute
- **THEN** the system SHALL respond with HTTP 429 Too Many Requests
- **AND** the system SHALL log the rate limit violation

### Requirement: Input Validation
The system SHALL validate all incoming requests to prevent injection attacks.

#### Scenario: Malicious request handling
- **WHEN** a request contains potentially malicious content
- **THEN** the system SHALL sanitize the input before logging
- **AND** the system SHALL still respond with HTTP 200 for the health check

### Requirement: Systemd Service Integration
The system SHALL run as a systemd service for proper process management on Ubuntu VPS.

#### Scenario: Service lifecycle
- **WHEN** the systemd service starts
- **THEN** the application SHALL bind to port 8001
- **AND** the application SHALL log startup completion
- **WHEN** the systemd service stops
- **THEN** the application SHALL gracefully shut down

### Requirement: Structured Logging
The system SHALL use structured JSON logging for compatibility with systemd journal.

#### Scenario: Log format
- **WHEN** logging any event
- **THEN** the log entry SHALL be in valid JSON format
- **AND** the log entry SHALL include timestamp, level, and message fields
- **AND** the log entry SHALL include relevant context fields (ip, user_agent, response_time)

### Requirement: MQTT Publish Endpoint
The system SHALL provide an HTTP endpoint that accepts GET requests with query parameter and publishes messages to MQTT broker.

#### Scenario: Successful MQTT publish with gate1
- **WHEN** a GET request is made to `/mqtt` endpoint with query parameter `gate=gate1`
- **THEN** the system SHALL respond with HTTP 200 status
- **AND** the response SHALL contain "OK" as the body
- **AND** the system SHALL publish a message to the configured MQTT topic for gate1

#### Scenario: Successful MQTT publish with gate2
- **WHEN** a GET request is made to `/mqtt` endpoint with query parameter `gate=gate2`
- **THEN** the system SHALL respond with HTTP 200 status
- **AND** the response SHALL contain "OK" as the body
- **AND** the system SHALL publish a message to the configured MQTT topic for gate2

#### Scenario: Invalid gate value
- **WHEN** a GET request is made to `/mqtt` endpoint with invalid gate value
- **THEN** the system SHALL respond with HTTP 400 status
- **AND** the system SHALL log the validation error

#### Scenario: Missing gate parameter
- **WHEN** a GET request is made to `/mqtt` endpoint without gate parameter
- **THEN** the system SHALL respond with HTTP 400 status
- **AND** the system SHALL log the missing parameter error

### Requirement: MQTT Configuration
The system SHALL load MQTT broker connection settings from a configuration file.

#### Scenario: Load MQTT configuration
- **WHEN** the application starts
- **THEN** the system SHALL read MQTT broker URL, client ID, username, and password from config file
- **AND** the system SHALL establish connection to MQTT broker using these credentials
- **AND** the system SHALL log successful connection or connection failure

#### Scenario: Missing configuration file
- **WHEN** the configuration file is not found
- **THEN** the system SHALL log an error
- **AND** the system SHALL exit with error status

#### Scenario: Invalid configuration
- **WHEN** the configuration file contains invalid or missing required fields
- **THEN** the system SHALL log the validation error
- **AND** the system SHALL exit with error status

### Requirement: MQTT Topic Mapping
The system SHALL map gate values to specific MQTT topics and payloads based on configuration.

#### Scenario: Map gate1 to topic and payload
- **WHEN** a request contains `gate=gate1`
- **THEN** the system SHALL publish to the MQTT topic configured for gate1
- **AND** the system SHALL use the payload configured for gate1

#### Scenario: Map gate2 to topic and payload
- **WHEN** a request contains `gate=gate2`
- **THEN** the system SHALL publish to the MQTT topic configured for gate2
- **AND** the system SHALL use the payload configured for gate2

### Requirement: MQTT Publish Logging
The system SHALL log all MQTT publish operations and errors.

#### Scenario: Log successful publish
- **WHEN** a message is successfully published to MQTT broker
- **THEN** the system SHALL log the publish operation with topic, gate, and payload

#### Scenario: Log publish failure
- **WHEN** MQTT publish operation fails
- **THEN** the system SHALL log the error with details
- **AND** the system SHALL still respond with HTTP 200 to the HTTP client

#### Scenario: Log publish attempt
- **WHEN** attempting to publish to MQTT broker
- **THEN** the system SHALL log the attempt with gate, topic, and payload

### Requirement: MQTT Error Handling
The system SHALL handle MQTT connection and publish errors gracefully.

#### Scenario: MQTT broker unavailable
- **WHEN** MQTT broker is not available
- **THEN** the system SHALL log the connection error
- **AND** the system SHALL continue to serve HTTP health check requests
- **AND** the system SHALL attempt to reconnect on next publish request

#### Scenario: MQTT authentication failure
- **WHEN** MQTT authentication fails
- **THEN** the system SHALL log the authentication error
- **AND** the system SHALL continue to serve HTTP requests

#### Scenario: MQTT connection lost
- **WHEN** MQTT connection is lost
- **THEN** the system SHALL log the connection loss
- **AND** the system SHALL automatically attempt to reconnect
- **AND** the system SHALL continue to serve HTTP requests

### Requirement: MQTT Rate Limiting
The system SHALL apply rate limiting to the MQTT publish endpoint to prevent abuse.

#### Scenario: MQTT rate limit enforcement
- **WHEN** more than 10 requests are received from the same IP within 1 minute to `/mqtt` endpoint
- **THEN** the system SHALL respond with HTTP 429 Too Many Requests
- **AND** the system SHALL log the rate limit violation

### Requirement: MQTT Client Lifecycle
The system SHALL properly manage MQTT client lifecycle during application startup and shutdown.

#### Scenario: MQTT client initialization
- **WHEN** the application starts
- **THEN** the system SHALL initialize MQTT client with configuration
- **AND** the system SHALL attempt to connect to MQTT broker
- **AND** the system SHALL log initialization status

#### Scenario: MQTT client graceful shutdown
- **WHEN** the application receives shutdown signal
- **THEN** the system SHALL disconnect MQTT client
- **AND** the system SHALL log the disconnection

