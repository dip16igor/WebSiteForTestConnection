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

// log logs a message with the specified level
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
		}
	}
	
	jsonEntry, err := json.Marshal(entry)
	if err != nil {
		log.Printf("Failed to marshal log entry: %v", err)
		return
	}
	
	fmt.Println(string(jsonEntry))
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

// getClientIP extracts the real client IP from the request
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
		
		// Set security headers
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

func main() {
	logger := NewLogger("health-check-server")
	rateLimiter := NewRateLimiter(10, time.Minute) // 10 requests per minute per IP
	
	// Create HTTP server with timeouts
	server := &http.Server{
		Addr:         ":8001",
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	
	// Setup routes
	http.HandleFunc("/", healthCheckHandler(logger, rateLimiter))
	
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