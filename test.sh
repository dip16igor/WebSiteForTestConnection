#!/bin/bash

# Health Check Server Test Script
# This script tests various aspects of the health check server

set -e

SERVER_URL="http://localhost:8001"
TEST_COUNT=0
PASS_COUNT=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Test $TEST_COUNT: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo "  ✅ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ❌ FAIL"
        echo "    Command: $test_command"
        echo "    Expected: $expected_result"
    fi
    echo ""
}

# Function to test response
test_response() {
    local test_name="$1"
    local url="$2"
    local expected_status="$3"
    local expected_body="$4"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Test $TEST_COUNT: $test_name"
    
    local response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
    local body=$(echo "$response" | head -n -1)
    local status=$(echo "$response" | tail -n 1)
    
    if [ "$status" = "$expected_status" ] && [ "$body" = "$expected_body" ]; then
        echo "  ✅ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ❌ FAIL"
        echo "    Expected status: $expected_status, got: $status"
        echo "    Expected body: '$expected_body', got: '$body'"
    fi
    echo ""
}

# Function to test headers
test_headers() {
    local test_name="$1"
    local url="$2"
    local header="$3"
    local expected_value="$4"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo "Test $TEST_COUNT: $test_name"
    
    local header_value=$(curl -s -I "$url" 2>/dev/null | grep -i "$header" | cut -d' ' -f2- | tr -d '\r\n')
    
    if [ "$header_value" = "$expected_value" ]; then
        echo "  ✅ PASS"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ❌ FAIL"
        echo "    Expected $header: $expected_value, got: '$header_value'"
    fi
    echo ""
}

echo "=== Health Check Server Test Suite ==="
echo "Testing server at: $SERVER_URL"
echo ""

# Check if server is running
if ! curl -s "$SERVER_URL" > /dev/null 2>&1; then
    echo "❌ Server is not responding at $SERVER_URL"
    echo "Please ensure the server is running before running tests"
    exit 1
fi

# Basic functionality tests
test_response "Basic health check" "$SERVER_URL" "200" "OK"
test_response "HTTPS should fail" "https://localhost:8001" "000" "" || echo "  (Expected - HTTPS not configured)"

# Method tests
echo "Test $((TEST_COUNT + 1)): POST method should be rejected"
TEST_COUNT=$((TEST_COUNT + 1))
if curl -s -w "%{http_code}" -X POST "$SERVER_URL" 2>/dev/null | grep -q "405"; then
    echo "  ✅ PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  ❌ FAIL - POST should return 405 Method Not Allowed"
fi
echo ""

# Security headers tests
test_headers "X-Content-Type-Options header" "$SERVER_URL" "X-Content-Type-Options" "nosniff"
test_headers "X-Frame-Options header" "$SERVER_URL" "X-Frame-Options" "DENY"
test_headers "X-XSS-Protection header" "$SERVER_URL" "X-XSS-Protection" "1; mode=block"

# Rate limiting test
echo "Test $((TEST_COUNT + 1)): Rate limiting (11 requests in quick succession)"
TEST_COUNT=$((TEST_COUNT + 1))
rate_limit_hits=0
for i in {1..11}; do
    status=$(curl -s -w "%{http_code}" "$SERVER_URL" 2>/dev/null | tail -n 1)
    if [ "$status" = "429" ]; then
        rate_limit_hits=$((rate_limit_hits + 1))
    fi
done

if [ $rate_limit_hits -gt 0 ]; then
    echo "  ✅ PASS - Rate limiting triggered after $rate_limit_hits requests"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  ❌ FAIL - Rate limiting did not trigger"
fi
echo ""

# Performance test
echo "Test $((TEST_COUNT + 1)): Response time should be under 100ms"
TEST_COUNT=$((TEST_COUNT + 1))
start_time=$(date +%s%N)
curl -s "$SERVER_URL" > /dev/null 2>&1
end_time=$(date +%s%N)
response_time=$(( (end_time - start_time) / 1000000 ))

if [ $response_time -lt 100 ]; then
    echo "  ✅ PASS - Response time: ${response_time}ms"
    PASS_COUNT=$((PASS_COUNT + 1))
else
    echo "  ❌ FAIL - Response time: ${response_time}ms (should be < 100ms)"
fi
echo ""

# Logging test
echo "Test $((TEST_COUNT + 1)): Check if logs are being generated"
TEST_COUNT=$((TEST_COUNT + 1))
if command -v journalctl &> /dev/null; then
    if journalctl -u health-check-server --since "1 minute ago" | grep -q "Health check request processed"; then
        echo "  ✅ PASS - Logs are being generated"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ❌ FAIL - No logs found in the last minute"
    fi
else
    echo "  ⚠️  SKIP - journalctl not available"
fi
echo ""

# Service status test
echo "Test $((TEST_COUNT + 1)): Service status"
TEST_COUNT=$((TEST_COUNT + 1))
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet health-check-server; then
        echo "  ✅ PASS - Service is running"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  ❌ FAIL - Service is not running"
    fi
else
    echo "  ⚠️  SKIP - systemctl not available"
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo "Tests run: $TEST_COUNT"
echo "Tests passed: $PASS_COUNT"
echo "Tests failed: $((TEST_COUNT - PASS_COUNT))"

if [ $PASS_COUNT -eq $TEST_COUNT ]; then
    echo "🎉 All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi