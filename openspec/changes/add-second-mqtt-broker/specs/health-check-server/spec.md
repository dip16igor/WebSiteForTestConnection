## ADDED Requirements

### Requirement: Second MQTT Broker Configuration
The system SHALL load connection settings for a second MQTT broker from the configuration file.

#### Scenario: Load second MQTT configuration
- **WHEN** the application starts
- **THEN** the system SHALL read second MQTT broker URL, client ID, username, and password from config file
- **AND** the system SHALL establish connection to the second MQTT broker using these credentials
- **AND** the system SHALL log successful connection or connection failure for second broker

#### Scenario: Missing second broker configuration
- **WHEN** the second MQTT broker configuration fields are not present in config file
- **THEN** the system SHALL log a warning
- **AND** the system SHALL continue operation without second broker

#### Scenario: Invalid second broker configuration
- **WHEN** the second MQTT broker configuration contains invalid or missing required fields
- **THEN** the system SHALL log the validation error
- **AND** the system SHALL continue operation without second broker

### Requirement: Second MQTT Client Lifecycle
The system SHALL properly manage the second MQTT client lifecycle during application startup and shutdown.

#### Scenario: Second MQTT client initialization
- **WHEN** the application starts
- **THEN** the system SHALL initialize the second MQTT client with its configuration
- **AND** the system SHALL attempt to connect to the second MQTT broker
- **AND** the system SHALL log initialization status for second broker

#### Scenario: Second MQTT client graceful shutdown
- **WHEN** the application receives shutdown signal
- **THEN** the system SHALL disconnect the second MQTT client
- **AND** the system SHALL log the disconnection for second broker

### Requirement: Action Publish Endpoint
The system SHALL provide an HTTP endpoint that accepts GET requests with query parameter and publishes action messages to the second MQTT broker.

#### Scenario: Successful action publish with vol+
- **WHEN** a GET request is made to `/action` endpoint with query parameter `action=vol+`
- **THEN** the system SHALL respond with HTTP 200 status
- **AND** the response SHALL contain "OK" as the body
- **AND** the system SHALL publish message "vol+" to topic "Home/WebRadio2/Action" on the second MQTT broker

#### Scenario: Successful action publish with vol-
- **WHEN** a GET request is made to `/action` endpoint with query parameter `action=vol-`
- **THEN** the system SHALL respond with HTTP 200 status
- **AND** the response SHALL contain "OK" as the body
- **AND** the system SHALL publish message "vol-" to topic "Home/WebRadio2/Action" on the second MQTT broker

#### Scenario: Invalid action value
- **WHEN** a GET request is made to `/action` endpoint with invalid action value
- **THEN** the system SHALL respond with HTTP 400 status
- **AND** the system SHALL log the validation error

#### Scenario: Missing action parameter
- **WHEN** a GET request is made to `/action` endpoint without action parameter
- **THEN** the system SHALL respond with HTTP 400 status
- **AND** the system SHALL log the missing parameter error

### Requirement: Second MQTT Publish Logging
The system SHALL log all MQTT publish operations and errors for the second broker.

#### Scenario: Log successful publish to second broker
- **WHEN** a message is successfully published to the second MQTT broker
- **THEN** the system SHALL log the publish operation with topic, action, and payload

#### Scenario: Log publish failure to second broker
- **WHEN** MQTT publish operation fails on the second broker
- **THEN** the system SHALL log the error with details
- **AND** the system SHALL still respond with HTTP 200 to the HTTP client

#### Scenario: Log publish attempt to second broker
- **WHEN** attempting to publish to the second MQTT broker
- **THEN** the system SHALL log the attempt with action, topic, and payload

### Requirement: Second MQTT Error Handling
The system SHALL handle second MQTT broker connection and publish errors gracefully.

#### Scenario: Second MQTT broker unavailable
- **WHEN** the second MQTT broker is not available
- **THEN** the system SHALL log the connection error
- **AND** the system SHALL continue to serve HTTP health check requests
- **AND** the system SHALL attempt to reconnect on next publish request to second broker

#### Scenario: Second MQTT authentication failure
- **WHEN** MQTT authentication fails on the second broker
- **THEN** the system SHALL log the authentication error
- **AND** the system SHALL continue to serve HTTP requests

#### Scenario: Second MQTT connection lost
- **WHEN** the second MQTT connection is lost
- **THEN** the system SHALL log the connection loss
- **AND** the system SHALL automatically attempt to reconnect
- **AND** the system SHALL continue to serve HTTP requests

### Requirement: Second MQTT Rate Limiting
The system SHALL apply rate limiting to the action publish endpoint to prevent abuse.

#### Scenario: Action endpoint rate limit enforcement
- **WHEN** more than 10 requests are received from the same IP within 1 minute to `/action` endpoint
- **THEN** the system SHALL respond with HTTP 429 Too Many Requests
- **AND** the system SHALL log the rate limit violation
