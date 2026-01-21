#!/bin/bash

# Скрипт для тестирования проверки пути

echo "Тестирование проверки пути..."
echo "========================================"
echo ""

echo "1. Тест GET на / (должен работать):"
RESPONSE=$(curl -s http://localhost:8001/)
echo "   Ответ: $RESPONSE"
if [ "$RESPONSE" = "OK" ]; then
    echo "   ✓ GET на / работает"
else
    echo "   ✗ GET на / НЕ работает"
fi
echo ""

echo "2. Тест GET на /mqtt (должен вернуть 404):"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/mqtt)
echo "   HTTP код: $HTTP_CODE"
if [ "$HTTP_CODE" = "404" ]; then
    echo "   ✓ GET на /mqtt возвращает 404 (правильно!)"
else
    echo "   ✗ GET на /mqtt НЕ возвращает 404"
fi
echo ""

echo "3. Тест POST на /mqtt (должен работать):"
RESPONSE=$(curl -s -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}')
echo "   Ответ: $RESPONSE"
if [ "$RESPONSE" = "OK" ]; then
    echo "   ✓ POST на /mqtt работает"
else
    echo "   ✗ POST на /mqtt НЕ работает"
fi
echo ""

echo "4. Тест POST на /test (должен вернуть 404):"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:8001/test \
  -H "Content-Type: application/json" \
  -d '{"test":"data"}')
echo "   HTTP код: $HTTP_CODE"
if [ "$HTTP_CODE" = "404" ]; then
    echo "   ✓ POST на /test возвращает 404 (правильно!)"
else
    echo "   ✗ POST на /test НЕ возвращает 404"
fi
echo ""

echo "========================================"
echo "Вывод:"
echo "========================================"

if [ "$RESPONSE" = "OK" ]; then
    echo "✓ Проверка пути работает корректно!"
    echo ""
    echo "MQTT эндпоинт готов к использованию."
else
    echo "✗ Проверка пути НЕ работает корректно."
    echo ""
    echo "Проверьте логи:"
    echo "  sudo journalctl -u health-check.service -n 20"
fi
