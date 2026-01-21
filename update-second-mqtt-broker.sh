#!/bin/bash

# Скрипт для обновления health-check-server с поддержкой второго MQTT брокера
# Запускать на VPS как root или с sudo

set -e

echo "=== Обновление Health Check Server с поддержкой второго MQTT брокера ==="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода успешного сообщения
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Функция для вывода сообщения об ошибке
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Функция для вывода предупреждения
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Функция для вывода информационного сообщения
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Проверка, что запущен как root
if [[ $EUID -ne 0 ]]; then
    print_error "Этот скрипт должен быть запущен как root (используйте sudo)"
    exit 1
fi

# Переменные конфигурации
BINARY_NAME="health-check-server"
CONFIG_DIR="/etc/health-check-server"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/health-check.service"
WORK_DIR="/tmp/health-check-update"

# Шаг 1: Создание резервной копии текущего binary
echo "Шаг 1: Создание резервной копии текущего binary..."
if [ -f /usr/local/bin/$BINARY_NAME ]; then
    BACKUP_FILE="/usr/local/bin/$BINARY_NAME.backup.$(date +%Y%m%d_%H%M%S)"
    cp /usr/local/bin/$BINARY_NAME "$BACKUP_FILE"
    print_success "Резервная копия создана: $BACKUP_FILE"
else
    print_warning "Существующий binary не найден, создание резервной копии пропущено"
fi
echo ""

# Шаг 2: Создание рабочей директории
echo "Шаг 2: Создание рабочей директории..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
print_success "Рабочая директория создана: $WORK_DIR"
echo ""

# Шаг 3: Создание нового main.go
echo "Шаг 3: Создание нового main.go с поддержкой второго MQTT брокера..."
cat > main.go << 'GOEOF'
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
	Action       string `json:"action,omitempty"`
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
	MQTT  MQTTConfig  `yaml:"mqtt"`
	MQTT2 *MQTTConfig `yaml:"mqtt2,omitempty"`
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
		case "action":
			entry.Action = value
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

	// Validate required fields for first MQTT broker
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

	// Validate second MQTT broker if configured (optional)
	if config.MQTT2 != nil {
		if config.MQTT2.Broker == "" {
			return nil, fmt.Errorf("mqtt2.broker is required when mqtt2 is configured")
		}
		if config.MQTT2.ClientID == "" {
			return nil, fmt.Errorf("mqtt2.client_id is required when mqtt2 is configured")
		}
		// Username and password are optional for second broker too
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

// actionPublishHandler handles the action publish endpoint for second MQTT broker
func actionPublishHandler(logger *Logger, rateLimiter *RateLimiter, mqtt2Client *MQTTClient) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		startTime := time.Now()

		// Only allow GET requests
		if r.Method != http.MethodGet {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			logger.Error("Action publish: Method not allowed", map[string]string{
				"method": r.Method,
				"ip":     getClientIP(r),
			})
			return
		}

		clientIP := getClientIP(r)

		// Check rate limiting
		if !rateLimiter.IsAllowed(clientIP) {
			w.WriteHeader(http.StatusTooManyRequests)
			logger.Error("Action publish: Rate limit exceeded", map[string]string{
				"ip": clientIP,
			})
			return
		}

		// Parse action value from query parameter
		action := r.URL.Query().Get("action")
		if action == "" {
			w.WriteHeader(http.StatusBadRequest)
			logger.Error("Action publish: Missing action parameter", map[string]string{
				"ip": clientIP,
			})
			return
		}

		// Validate action value
		if action != "vol+" && action != "vol-" {
			w.WriteHeader(http.StatusBadRequest)
			logger.Error("Action publish: Invalid action value", map[string]string{
				"ip":     clientIP,
				"action": action,
			})
			return
		}

		// Fixed topic for WebRadio2
		topic := "Home/WebRadio2/Action"

		// Debug log before MQTT publish
		logger.Info("Action publish: Attempting to publish", map[string]string{
			"ip":     clientIP,
			"action": action,
			"topic":  topic,
		})

		// Publish to MQTT2 with action as payload
		var publishErr error
		if mqtt2Client != nil {
			publishErr = mqtt2Client.Publish(topic, action)
		} else {
			publishErr = fmt.Errorf("second MQTT broker not configured")
		}

		if publishErr != nil {
			// Log error but still respond with OK (best effort)
			logger.Error("Action publish: Failed to publish message", map[string]string{
				"ip":     clientIP,
				"action": action,
				"topic":  topic,
				"error":  publishErr.Error(),
			})
		} else {
			logger.Info("Action message published", map[string]string{
				"ip":     clientIP,
				"action": action,
				"topic":  topic,
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
		logger.Info("Action publish request processed", map[string]string{
			"ip":            clientIP,
			"action":        action,
			"topic":         topic,
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

	// Initialize first MQTT client
	mqttClient := NewMQTTClient(&config.MQTT, logger)

	// Connect to first MQTT broker
	if err := mqttClient.Connect(); err != nil {
		logger.Error("Failed to connect to MQTT broker", map[string]string{
			"error": err.Error(),
		})
		// Continue running even if MQTT connection fails (best effort)
	}

	// Initialize second MQTT client if configured
	var mqtt2Client *MQTTClient
	if config.MQTT2 != nil {
		mqtt2Client = NewMQTTClient(config.MQTT2, logger)
		// Connect to second MQTT broker
		if err := mqtt2Client.Connect(); err != nil {
			logger.Error("Failed to connect to second MQTT broker", map[string]string{
				"error": err.Error(),
			})
			// Continue running even if second MQTT connection fails (best effort)
			mqtt2Client = nil
		} else {
			logger.Info("Second MQTT broker connected", map[string]string{
				"broker": config.MQTT2.Broker,
			})
		}
	} else {
		logger.Info("Second MQTT broker not configured", nil)
	}

	// Create HTTP server with timeouts
	mux := http.NewServeMux()
	mux.Handle("/", healthCheckHandler(logger, rateLimiter))
	mux.Handle("/mqtt", mqttPublishHandler(logger, rateLimiter, mqttClient))
	mux.Handle("/action", actionPublishHandler(logger, rateLimiter, mqtt2Client))

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

	// Disconnect MQTT clients
	mqttClient.Disconnect()
	if mqtt2Client != nil {
		mqtt2Client.Disconnect()
	}

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
GOEOF

print_success "main.go создан"
echo ""

# Шаг 4: Проверка установки Go
echo "Шаг 4: Проверка установки Go..."
if ! command -v go &> /dev/null; then
    print_error "Go не установлен. Пожалуйста, установите Go:"
    echo "  apt update && apt install -y golang-go"
    exit 1
fi
GO_VERSION=$(go version | awk '{print $3}')
print_success "Go установлен: $GO_VERSION"
echo ""

# Шаг 5: Компиляция
echo "Шаг 5: Компиляция health-check-server..."
if go build -o $BINARY_NAME main.go; then
    print_success "Компиляция успешна"
else
    print_error "Компиляция не удалась"
    exit 1
fi
echo ""

# Шаг 6: Копирование binary
echo "Шаг 6: Копирование нового binary..."
cp $BINARY_NAME /usr/local/bin/
chmod +x /usr/local/bin/$BINARY_NAME
chown root:healthcheck /usr/local/bin/$BINARY_NAME
print_success "Binary скопирован и права установлены"
echo ""

# Шаг 7: Обновление конфигурации (добавление mqtt2)
echo "Шаг 7: Обновление конфигурации..."
if [ -f "$CONFIG_FILE" ]; then
    if ! grep -q "^mqtt2:" "$CONFIG_FILE"; then
        echo "" >> "$CONFIG_FILE"
        echo "# Second MQTT broker configuration (optional)" >> "$CONFIG_FILE"
        echo "# Used for WebRadio2 control via /action endpoint" >> "$CONFIG_FILE"
        echo "# Remove this section if not using a second broker" >> "$CONFIG_FILE"
        echo "mqtt2:" >> "$CONFIG_FILE"
        echo "  # MQTT broker address (tcp://hostname:port)" >> "$CONFIG_FILE"
        echo "  broker: \"tcp://46.8.233.146:1883\"" >> "$CONFIG_FILE"
        echo "  " >> "$CONFIG_FILE"
        echo "  # MQTT client ID (must be unique)" >> "$CONFIG_FILE"
        echo "  client_id: \"IgorSmartWatch-WebRadio2\"" >> "$CONFIG_FILE"
        echo "  " >> "$CONFIG_FILE"
        echo "  # Authentication credentials" >> "$CONFIG_FILE"
        echo "  username: \"dip16\"" >> "$CONFIG_FILE"
        echo "  password: \"nirvana7\"" >> "$CONFIG_FILE"
        echo "  " >> "$CONFIG_FILE"
        echo "  # Quality of Service level (0, 1, or 2)" >> "$CONFIG_FILE"
        echo "  qos: 1" >> "$CONFIG_FILE"
        echo "  " >> "$CONFIG_FILE"
        echo "  # Whether to retain messages on the broker" >> "$CONFIG_FILE"
        echo "  retain: false" >> "$CONFIG_FILE"
        echo "  " >> "$CONFIG_FILE"
        echo "  # Connection timeout in seconds" >> "$CONFIG_FILE"
        echo "  connect_timeout: 10" >> "$CONFIG_FILE"
        print_success "Конфигурация обновлена с примером mqtt2"
    else
        print_info "Секция mqtt2 уже существует в конфигурации"
    fi
else
    print_warning "Файл конфигурации не найден, будет создан новый"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << 'EOF'
# MQTT Configuration for Health Check Server
# Update with your MQTT broker settings

mqtt:
  # MQTT broker address (tcp://hostname:port)
  broker: "tcp://78.29.40.170:1883"
  
  # MQTT client ID (must be unique)
  client_id: "IgorSmartWatch"
  
  # Authentication credentials
  username: ""
  password: ""
  
  # Quality of Service level (0, 1, or 2)
  qos: 1
  
  # Whether to retain messages on the broker
  retain: false
  
  # Connection timeout in seconds
  connect_timeout: 10
  
  # Gate configuration: topic and payload for each gate value
  gates:
    gate1:
      topic: "GateControl/Gate"
      payload: "179226315200"
    gate2:
      topic: "GateControl/Gate"
      payload: "279226315200"

# Second MQTT broker configuration (optional)
# Used for WebRadio2 control via /action endpoint
# Remove this section if not using a second broker
mqtt2:
  # MQTT broker address (tcp://hostname:port)
  broker: "tcp://46.8.233.146:1883"
  
  # MQTT client ID (must be unique)
  client_id: "IgorSmartWatch-WebRadio2"
  
  # Authentication credentials
  username: "dip16"
  password: "nirvana7"
  
  # Quality of Service level (0, 1, or 2)
  qos: 1
  
  # Whether to retain messages on the broker
  retain: false
  
  # Connection timeout in seconds
  connect_timeout: 10
EOF
    chmod 600 "$CONFIG_FILE"
    chown healthcheck:healthcheck "$CONFIG_FILE"
    print_success "Новый файл конфигурации создан"
fi
echo ""

# Шаг 8: Перезапуск сервиса
echo "Шаг 8: Перезапуск health check service..."
systemctl restart health-check.service
sleep 3
echo ""

# Шаг 9: Проверка статуса сервиса
echo "Шаг 9: Проверка статуса сервиса..."
if systemctl is-active --quiet health-check.service; then
    print_success "Health check сервис запущен"
else
    print_error "Health check сервис не запустился"
    echo ""
    echo "Проверка логов для ошибок:"
    journalctl -u health-check.service -n 20 --no-pager
    exit 1
fi
echo ""

# Шаг 10: Тестирование health check endpoint
echo "Шаг 10: Тестирование health check endpoint..."
if curl -f --max-time 5 http://localhost:8001 > /dev/null 2>&1; then
    print_success "Health check endpoint отвечает корректно"
else
    print_error "Health check endpoint не отвечает"
    echo ""
    echo "Проверка логов:"
    journalctl -u health-check.service -n 20 --no-pager
    exit 1
fi
echo ""

# Шаг 11: Тестирование MQTT publish endpoint
echo "Шаг 11: Тестирование MQTT publish endpoint..."
echo "Тестирование gate1..."
if curl -f "http://localhost:8001/mqtt?gate=gate1" --max-time 5 > /dev/null 2>&1; then
    print_success "MQTT publish для gate1 работает"
else
    print_warning "MQTT publish для gate1 не удался (может быть нормально, если MQTT брокер не настроен)"
fi

echo "Тестирование gate2..."
if curl -f "http://localhost:8001/mqtt?gate=gate2" --max-time 5 > /dev/null 2>&1; then
    print_success "MQTT publish для gate2 работает"
else
    print_warning "MQTT publish для gate2 не удался (может быть нормально, если MQTT брокер не настроен)"
fi
echo ""

# Шаг 12: Тестирование action endpoint
echo "Шаг 12: Тестирование action endpoint (второй MQTT брокер)..."
if curl -f "http://localhost:8001/action?action=vol+" --max-time 5 > /dev/null 2>&1; then
    print_success "Action endpoint для vol+ работает"
else
    print_warning "Action endpoint для vol+ не удался (может быть нормально, если второй MQTT брокер не настроен)"
fi

if curl -f "http://localhost:8001/action?action=vol-" --max-time 5 > /dev/null 2>&1; then
    print_success "Action endpoint для vol- работает"
else
    print_warning "Action endpoint для vol- не удался (может быть нормально, если второй MQTT брокер не настроен)"
fi
echo ""

# Шаг 13: Отображение последних логов
echo "Шаг 13: Отображение последних логов..."
echo "Последние логи health check server:"
journalctl -u health-check.service -n 15 --no-pager
echo ""

# Шаг 14: Отображение информации о сервисе
echo "Шаг 14: Информация о сервисе..."
echo ""
systemctl status health-check.service --no-pager
echo ""

# Очистка
echo "Очистка временных файлов..."
cd /
rm -rf "$WORK_DIR"
print_success "Временные файлы удалены"
echo ""

echo "=== Обновление завершено ==="
echo ""
echo "Health check server запущен на порту 8001"
echo ""
echo "Полезные команды:"
echo "  Проверить статус: systemctl status health-check.service"
echo "  Просмотреть логи: journalctl -u health-check.service -f"
echo "  Перезапустить сервис: systemctl restart health-check.service"
echo "  Остановить сервис: systemctl stop health-check.service"
echo "  Редактировать конфиг: nano /etc/health-check-server/config.yaml"
echo ""
echo "Расположение файла конфигурации: $CONFIG_FILE"
echo "Расположение binary: /usr/local/bin/$BINARY_NAME"
echo "Файл сервиса: $SERVICE_FILE"
echo ""
echo "Новый endpoint для второго MQTT брокера:"
echo "  curl \"http://<IP_VPS>:8001/action?action=vol+\""
echo "  curl \"http://<IP_VPS>:8001/action?action=vol-\""
echo ""
