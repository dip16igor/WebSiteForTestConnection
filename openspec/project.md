# Project Context

## Purpose
Simple web server for VPS health monitoring with MQTT integration. Provides HTTP 200 responses for health checks and publishes messages to MQTT broker for IoT system integration, with detailed logging for security and monitoring purposes.

## Tech Stack
- Go - Single binary, low memory footprint
- Systemd - Service management on Ubuntu VPS
- Standard Library HTTP server - Minimal dependencies, secure by default
- Eclipse Paho MQTT Go Client - MQTT broker integration for IoT systems
- YAML configuration - Flexible configuration management

## Project Conventions

### Code Style
- Go standard formatting (gofmt)
- Minimal dependencies principle
- Security-first approach with input validation
- Structured JSON logging for system integration

### Architecture Patterns
- Single-purpose microservice design
- Stateless operation for reliability
- Graceful shutdown handling
- Rate limiting for abuse prevention

### Testing Strategy
- Unit tests for core functionality
- Integration tests for HTTP endpoints
- Security testing for input validation
- Load testing for rate limiting

### Git Workflow
- Feature branches for new capabilities
- Change proposals via OpenSpec process
- Semantic versioning for releases

## Domain Context
VPS health monitoring server designed for Ubuntu environments. The server provides a simple HTTP endpoint that monitoring systems can ping to verify VPS availability and responsiveness.

## Important Constraints
- Must run on Ubuntu VPS with systemd
- Port 8001 must be available and not blocked by firewall
- Memory usage should be minimal (< 50MB)
- No external dependencies beyond Go standard library
- Must be secure against common web attacks

## External Dependencies
- systemd for service management
- Ubuntu firewall (ufw) configuration
- systemd journal for logging
- Monitoring systems that will ping the health endpoint
