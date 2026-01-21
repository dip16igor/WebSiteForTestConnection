#!/bin/bash

# Скрипт для тестирования IPv4 и IPv6

echo "Тестирование IPv4 и IPv6..."
echo "========================================"
echo ""

echo "1. Проверка, какие адреса слушает сервер:"
sudo netstat -tlnp | grep 8001
echo ""

echo "2. Тест IPv4 (127.0.0.1):"
curl -v -X POST http://127.0.0.1:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}' 2>&1 | grep -E "(< HTTP|< Content-Type|OK|Method not allowed)"
echo ""

echo "3. Тест IPv6 (::1):"
curl -v -X POST http://[::1]:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}' 2>&1 | grep -E "(< HTTP|< Content-Type|OK|Method not allowed)"
echo ""

echo "4. Тест localhost (автоматический выбор):"
curl -v -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}' 2>&1 | grep -E "(< HTTP|< Content-Type|OK|Method not allowed)"
echo ""

echo "5. Проверка логов после тестов:"
echo "========================================"
sudo journalctl -u health-check.service -n 5 --no-pager
