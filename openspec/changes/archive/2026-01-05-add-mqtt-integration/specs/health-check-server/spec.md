## ADDED Requirements

### Requirement: MQTT Publish Endpoint
The system SHALL provide an HTTP endpoint that accepts GET requests with JSON body and publishes messages to MQTT broker.

#### Scenario: Successful MQTT publish with gate1
- **WHEN** a GET request is made to `/mqtt` endpoint with JSON body `{"gate": "gate1"}`
- **THEN** the system SHALL respond with HTTP 200 status
- **AND** the response SHALL contain "OK" as the body
- **AND** the system SHALL publish a message to the configured MQTT topic for gate1

#### Scenario: Successful MQTT publish with gate2
- **WHEN** a GET request is made to `/mqtt` endpoint with JSON body `{"gate": "gate2"}`
- **THEN** the system SHALL respond with HTTP 200 status
- **AND** the response SHALL contain "OK" as the body
- **AND** the system SHALL publish a message to the configured MQTT topic for gate2

#### Scenario: Invalid gate value
- **WHEN** a GET request is made to `/mqtt` endpoint with JSON body containing invalid gate value
- **THEN** the system SHALL respond with HTTP 400 status
- **AND** the system SHALL log the validation error

### Requirement: MQTT Configuration
The system SHALL load MQTT broker connection settings from a configuration file.

#### Scenario: Load MQTT configuration
- **WHEN** the application starts
- **THEN** the system SHALL read MQTT broker URL, port, username, and password from config file
- **AND** the system SHALL establish connection to MQTT broker using these credentials
- **AND** the system SHALL log successful connection or connection failure

#### Scenario: Missing configuration file
- **WHEN** the configuration file is not found
- **THEN** the system SHALL log an error
- **AND** the system SHALL exit with error status

### Requirement: MQTT Topic Mapping
The system SHALL map gate values to specific MQTT topics based on configuration.

#### Scenario: Map gate1 to topic
- **WHEN** a request contains `{"gate": "gate1"}`
- **THEN** the system SHALL publish to the MQTT topic configured for gate1

#### Scenario: Map gate2 to topic
- **WHEN** a request contains `{"gate": "gate2"}`
- **THEN** the system SHALL publish to the MQTT topic configured for gate2

### Requirement: MQTT Publish Logging
The system SHALL log all MQTT publish operations and errors.

#### Scenario: Log successful publish
- **WHEN** a message is successfully published to MQTT broker
- **THEN** the system SHALL log the publish operation with topic and gate value

#### Scenario: Log publish failure
- **WHEN** MQTT publish operation fails
- **THEN** the system SHALL log the error with details
- **AND** the system SHALL still respond with HTTP 200 to the HTTP client

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
- **AND** the system SHALL respond with HTTP 500 status to MQTT publish requests
