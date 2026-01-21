#!/bin/bash

# Скрипт для тестирования MQTT эндпоинта

echo "Тестирование MQTT эндпоинта..."
echo "========================================"
echo ""

echo "1. Тест с полным URL:"
curl -v -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}' 2>&1 | grep -E "(< HTTP|< Content-Type|< X-|OK|Method not allowed)"
echo ""

echo "2. Тест gate2:"
curl -v -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate2"}' 2>&1 | grep -E "(< HTTP|< Content-Type|< X-|OK|Method not allowed)"
echo ""

echo "3. Проверка, какой эндпоинт отвечает:"
echo "   Попробуйте GET на /mqtt (должно вернуть 'Method not allowed'):"
curl -v http://localhost:8001/mqtt 2>&1 | grep -E "(< HTTP|< Content-Type|Method not allowed)"
echo ""

echo "========================================"
echo "Просмотр последних логов:"
echo "========================================"
sudo journalctl -u health-check.service -n 10 --no-pager | tail -5
