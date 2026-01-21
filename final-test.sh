#!/bin/bash

# Финальный тестовый скрипт

echo "Финальное тестирование..."
echo "========================================"
echo ""

echo "1. Проверка бинарника на VPS:"
BINARY="/etc/health-check-server/health-check-server"
if strings "$BINARY" | grep -q "Only handle root path"; then
    echo "   ✓ Бинарник содержит исправление маршрутизации"
else
    echo "   ✗ Бинарник НЕ содержит исправление маршрутизации"
    echo ""
    echo "   Нужно перекомпилировать:"
    echo "   cd /tmp/health-check-deploy"
    echo "   /usr/local/go/bin/go build -o health-check-server main.go"
    echo "   sudo cp health-check-server $BINARY"
    echo "   sudo systemctl restart health-check.service"
    exit 1
fi
echo ""

echo "2. Тест MQTT эндпоинта:"
RESPONSE=$(curl -s -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}')

if [ "$RESPONSE" = "OK" ]; then
    echo "   ✓ MQTT эндпоинт работает! Ответ: $RESPONSE"
else
    echo "   ✗ MQTT эндпоинт НЕ работает! Ответ: $RESPONSE"
    echo ""
    echo "   Проверьте логи:"
    echo "   sudo journalctl -u health-check.service -n 10"
fi
echo ""

echo "3. Последние логи:"
sudo journalctl -u health-check.service -n 5 --no-pager
