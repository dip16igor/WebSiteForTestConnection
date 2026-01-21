package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"gopkg.in/yaml.v3"
)

// Logger represents a structured JSON logger
type Logger struct {
	prefix string
}

// LogEntry represents a structured log entry
type LogEntry struct {
	Timestamp    string `json:"timestamp"`
	Level        string `json:"level"`
	Message      string `json:"message"`
	IP           string `json:"ip,omitempty"`
	UserAgent    string `json:"user_agent,omitempty"`
	ResponseTime string `json:"response_time_ms,omitempty"`
	Gate         string `json:"gate,omitempty"`
	Topic        string `json:"topic,omitempty"`
	Payload      string `json:"payload,omitempty"`
	Error        string `json:"error,omitempty"`
}

// RateLimiter implements a simple rate limiter
type RateLimiter struct {
	clients map[string][]time.Time
	mutex   sync.RWMutex
	limit   int
	window  time.Duration
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		clients: make(map[string][]time.Time),
		limit:   limit,
		window:  window,
	}
}

// IsAllowed checks if a client is allowed to make a request
func (rl *RateLimiter) IsAllowed(ip string) bool {
	rl.mutex.Lock()
	defer rl.mutex.Unlock()

	now := time.Now()

	// Clean old entries
	if requests, exists := rl.clients[ip]; exists {
		var validRequests []time.Time
		for _, reqTime := range requests {
			if now.Sub(reqTime) < rl.window {
				validRequests = append(validRequests, reqTime)
			}
		}
		rl.clients[ip] = validRequests
	}

	// Check limit
	if len(rl.clients[ip]) >= rl.limit {
		return false
	}

	// Add current request
	rl.clients[ip] = append(rl.clients[ip], now)
	return true
}

// GateConfig holds configuration for a single gate
type GateConfig struct {
	Topic   string `yaml:"topic"`
	Payload  string `yaml:"payload"`
}

// MQTTConfig holds MQTT broker configuration
type MQTTConfig struct {
	Broker         string                 `yaml:"broker"`
	ClientID       string                 `yaml:"client_id"`
	Username       string                 `yaml:"username"`
	Password       string                 `yaml:"password"`
	QoS            byte                   `yaml:"qos"`
	Retain         bool                   `yaml:"retain"`
	ConnectTimeout int                    `yaml:"connect_timeout"`
	Gates          map[string]GateConfig   `yaml:"gates"`
}

// Config holds application configuration
type Config struct {
	MQTT MQTTConfig `yaml:"mqtt"`
}

// MQTTClient wraps Paho MQTT client
type MQTTClient struct {
	client mqtt.Client
	config *MQTTConfig
	logger *Logger
	connected bool
	mutex   sync.RWMutex
}

// NewLogger creates a new structured logger
func NewLogger(prefix string) *Logger {
	return &Logger{prefix: prefix}
}

// Info logs an info message
func (l *Logger) Info(message string, fields map[string]string) {
	l.log("info", message, fields)
}

// Error logs an error message
func (l *Logger) Error(message string, fields map[string]string) {
	l.log("error", message, fields)
}

// log logs a message with specified level
func (l *Logger) log(level, message string, fields map[string]string) {
	entry := LogEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Level:     level,
		Message:   message,
	}

	for key, value := range fields {
		switch key {
		case "ip":
			entry.IP = value
		case "user_agent":
			entry.UserAgent = value
		case "response_time":
			entry.ResponseTime = value
		case "gate":
			entry.Gate = value
		case "topic":
			entry.Topic = value
		case "payload":
			entry.Payload = value
		case "error":
			entry.Error = value
		}
	}

	jsonEntry, err := json.Marshal(entry)
	if err != nil {
		log.Printf("Failed to marshal log entry: %v", err)
		return
	}

	// Write to stderr for systemd journal capture
	fmt.Fprintln(os.Stderr, string(jsonEntry))
}

// loadConfig loads configuration from file
func loadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	// Validate required fields
	if config.MQTT.Broker == "" {
		return nil, fmt.Errorf("mqtt.broker is required")
	}
	if config.MQTT.ClientID == "" {
		return nil, fmt.Errorf("mqtt.client_id is required")
	}
	// Username and password are optional (can be empty for no authentication)
	if len(config.MQTT.Gates) == 0 {
		return nil, fmt.Errorf("mqtt.gates is required")
	}
	if _, ok := config.MQTT.Gates["gate1"]; !ok {
		return nil, fmt.Errorf("mqtt.gates.gate1 is required")
	}
	if _, ok := config.MQTT.Gates["gate2"]; !ok {
		return nil, fmt.Errorf("mqtt.gates.gate2 is required")
	}

	return &config, nil
}

// NewMQTTClient creates a new MQTT client
func NewMQTTClient(config *MQTTConfig, logger *Logger) *MQTTClient {
	opts := mqtt.NewClientOptions()
	opts.AddBroker(config.Broker)
	opts.SetClientID(config.ClientID)
	opts.SetUsername(config.Username)
	opts.SetPassword(config.Password)
	opts.SetAutoReconnect(true)
	opts.SetMaxReconnectInterval(30 * time.Second)
	opts.SetConnectTimeout(time.Duration(config.ConnectTimeout) * time.Second)
	opts.SetCleanSession(true)

	// Set connection handler
	opts.OnConnect = func(client mqtt.Client) {
		logger.Info("MQTT client connected", map[string]string{
			"broker": config.Broker,
		})
	}

	opts.OnConnectionLost = func(client mqtt.Client, err error) {
		logger.Error("MQTT connection lost", map[string]string{
			"error": err.Error(),
		})
	}

	return &MQTTClient{
		client: mqtt.NewClient(opts),
		config: config,
		logger: logger,
		connected: false,
	}
}

// Connect establishes connection to MQTT broker
func (m *MQTTClient) Connect() error {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	if m.connected {
		return nil
	}

	token := m.client.Connect()
	if token.Wait() && token.Error() != nil {
		return fmt.Errorf("failed to connect to MQTT broker: %w", token.Error())
	}

	m.connected = true
	return nil
}

// Publish publishes a message to specified topic
func (m *MQTTClient) Publish(topic, payload string) error {
	m.mutex.RLock()
	defer m.mutex.RUnlock()

	if !m.connected {
		// Try to connect if not connected
		if err := m.Connect(); err != nil {
			return fmt.Errorf("not connected to MQTT broker: %w", err)
		}
	}

	token := m.client.Publish(topic, m.config.QoS, m.config.Retain, payload)
	if token.Wait() && token.Error() != nil {
		return fmt.Errorf("failed to publish message: %w", token.Error())
	}

	return nil
}

// Disconnect closes MQTT connection
func (m *MQTTClient) Disconnect() {
	m.mutex.Lock()
	defer m.mutex.Unlock()

	if m.connected {
		m.client.Disconnect(250)
		m.connected = false
		m.logger.Info("MQTT client disconnected", nil)
	}
}

// GetGateConfig returns MQTT topic and payload for a given gate value
func (m *MQTTClient) GetGateConfig(gate string) (*GateConfig, error) {
	gateConfig, ok := m.config.Gates[gate]
	if !ok {
		return nil, fmt.Errorf("invalid gate value: %s", gate)
	}
	return &gateConfig, nil
}

// sanitizeInput sanitizes input to prevent injection
func sanitizeInput(input string) string {
	// Remove newlines and other potentially dangerous characters
	input = strings.ReplaceAll(input, "\n", "")
	input = strings.ReplaceAll(input, "\r", "")
	input = strings.ReplaceAll(input, "\t", "")

	// Limit length
	if len(input) > 500 {
		input = input[:500]
	}

	return input
}

// getClientIP extracts real client IP from request
func getClientIP(r *http.Request) string {
	// Check X-Forwarded-For header first
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		// Take the first IP if multiple are listed
		ips := strings.Split(xff, ",")
		if len(ips) > 0 {
			ip := strings.TrimSpace(ips[0])
			if net.ParseIP(ip) != nil {
				return ip
			}
		}
	}

	// Check X-Real-IP header
	if xri := r.Header.Get("X-Real-IP"); xri != "" {
		if net.ParseIP(xri) != nil {
			return xri
		}
	}

	// Fall back to RemoteAddr
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return ip
}

// healthCheckHandler handles the health check endpoint
func healthCheckHandler(logger *Logger, rateLimiter *RateLimiter) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		startTime := time.Now()

		// Only allow GET requests
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			logger.Error("Method not allowed", map[string]string{
				"method": r.Method,
				"ip":     getClientIP(r),
			})
			return
		}

		clientIP := getClientIP(r)

		// Check rate limiting
		if !rateLimiter.IsAllowed(clientIP) {
			w.WriteHeader(http.StatusTooManyRequests)
			logger.Error("Rate limit exceeded", map[string]string{
				"ip": clientIP,
			})
			return
		}

		// Sanitize user agent
		userAgent := sanitizeInput(r.Header.Get("User-Agent"))

		// Set security headers BEFORE writing status
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")

		// Send response
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "OK")

		// Calculate response time
		responseTime := time.Since(startTime).Milliseconds()

		// Log the request
		logger.Info("Health check request processed", map[string]string{
			"ip":            clientIP,
			"user_agent":    userAgent,
			"response_time": fmt.Sprintf("%d", responseTime),
		})
	}
}

// mqttPublishHandler handles the MQTT publish endpoint
func mqttPublishHandler(logger *Logger, rateLimiter *RateLimiter, mqttClient *MQTTClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		startTime := time.Now()

		// Only allow GET requests
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			logger.Error("MQTT publish: Method not allowed", map[string]string{
				"method": r.Method,
				"ip":     getClientIP(r),
			})
			return
		}

		clientIP := getClientIP(r)

		// Check rate limiting
		if !rateLimiter.IsAllowed(clientIP) {
			w.WriteHeader(http.StatusTooManyRequests)
			logger.Error("MQTT publish: Rate limit exceeded", map[string]string{
				"ip": clientIP,
			})
			return
		}

		// Parse gate value from query parameter
		gate := r.URL.Query().Get("gate")
		if gate == "" {
			w.WriteHeader(http.StatusBadRequest)
			logger.Error("MQTT publish: Missing gate parameter", map[string]string{
				"ip": clientIP,
			})
			return
		}

		// Validate gate value
		if gate != "gate1" && gate != "gate2" {
			w.WriteHeader(http.StatusBadRequest)
			logger.Error("MQTT publish: Invalid gate value", map[string]string{
				"ip":   clientIP,
				"gate": gate,
			})
			return
		}

		// Get gate configuration (topic and payload)
		gateConfig, err := mqttClient.GetGateConfig(gate)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			logger.Error("MQTT publish: Failed to get gate config", map[string]string{
				"ip":    clientIP,
				"gate":  gate,
				"error": err.Error(),
			})
			return
		}

		// Debug log before MQTT publish
		logger.Info("MQTT publish: Attempting to publish", map[string]string{
			"ip":     clientIP,
			"gate":   gate,
			"topic":   gateConfig.Topic,
			"payload": gateConfig.Payload,
		})

		// Publish to MQTT with configured payload
		publishErr := mqttClient.Publish(gateConfig.Topic, gateConfig.Payload)
		if publishErr != nil {
			// Log error but still respond with OK (best effort)
			logger.Error("MQTT publish: Failed to publish message", map[string]string{
				"ip":     clientIP,
				"gate":   gate,
				"topic":   gateConfig.Topic,
				"payload": gateConfig.Payload,
				"error":   publishErr.Error(),
			})
		} else {
			logger.Info("MQTT message published", map[string]string{
				"ip":     clientIP,
				"gate":   gate,
				"topic":   gateConfig.Topic,
				"payload": gateConfig.Payload,
			})
		}

		// Set security headers BEFORE writing status
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("X-XSS-Protection", "1; mode=block")
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")

		// Send response
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "OK")

		// Calculate response time
		responseTime := time.Since(startTime).Milliseconds()

		// Log the request
		logger.Info("MQTT publish request processed", map[string]string{
			"ip":            clientIP,
			"gate":          gate,
			"topic":         gateConfig.Topic,
			"payload":       gateConfig.Payload,
			"response_time": fmt.Sprintf("%d", responseTime),
		})
	}
}

func main() {
	logger := NewLogger("health-check-server")
	rateLimiter := NewRateLimiter(10, time.Minute) // 10 requests per minute per IP

	// Load configuration
	config, err := loadConfig("config.yaml")
	if err != nil {
		logger.Error("Failed to load configuration", map[string]string{
			"error": err.Error(),
		})
		os.Exit(1)
	}

	// Initialize MQTT client
	mqttClient := NewMQTTClient(&config.MQTT, logger)

	// Connect to MQTT broker
	if err := mqttClient.Connect(); err != nil {
		logger.Error("Failed to connect to MQTT broker", map[string]string{
			"error": err.Error(),
		})
		// Continue running even if MQTT connection fails (best effort)
	}

	// Create HTTP server with timeouts
	mux := http.NewServeMux()
	mux.Handle("/", healthCheckHandler(logger, rateLimiter))
	mux.Handle("/mqtt", mqttPublishHandler(logger, rateLimiter, mqttClient))

	server := &http.Server{
		Addr:         ":8001",
		Handler:       mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in a goroutine
	go func() {
		logger.Info("Starting health check server on port 8001", nil)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("Failed to start server", map[string]string{
				"error": err.Error(),
			})
			os.Exit(1)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down health check server", nil)

	// Disconnect MQTT client
	mqttClient.Disconnect()

	// Create a deadline for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Attempt graceful shutdown
	if err := server.Shutdown(ctx); err != nil {
		logger.Error("Server forced to shutdown", map[string]string{
			"error": err.Error(),
		})
		os.Exit(1)
	}

	logger.Info("Health check server stopped", nil)
}
