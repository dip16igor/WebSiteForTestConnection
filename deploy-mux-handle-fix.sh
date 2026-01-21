#!/bin/bash

# Финальный скрипт деплоя с mux.Handle

echo "Финальный деплой с mux.Handle..."
echo "========================================"
echo ""

echo "1. Очистка кеша Go:"
cd /tmp/health-check-deploy
/usr/local/go/bin/go clean -cache
echo "   ✓ Кеш очищен"
echo ""

echo "2. Компиляция с флагом -a (без оптимизации):"
/usr/local/go/bin/go build -a -o health-check-server main.go
if [ $? -eq 0 ]; then
    echo "   ✓ Бинарник скомпилирован"
else
    echo "   ✗ Ошибка компиляции!"
    exit 1
fi
echo ""

echo "3. Копирование бинарника:"
sudo cp health-check-server /etc/health-check-server/
if [ $? -eq 0 ]; then
    echo "   ✓ Бинарник скопирован"
else
    echo "   ✗ Ошибка копирования!"
    exit 1
fi
echo ""

echo "4. Перезагрузка сервиса:"
sudo systemctl restart health-check.service
if [ $? -eq 0 ]; then
    echo "   ✓ Сервис перезапущен"
else
    echo "   ✗ Ошибка перезапуска!"
    exit 1
fi
echo ""

echo "5. Ожидание запуска:"
sleep 3
echo ""

echo "========================================"
echo "Тестирование:"
echo "========================================"
echo ""

echo "Тест 1: GET на /"
RESPONSE=$(curl -s http://localhost:8001/)
if [ "$RESPONSE" = "OK" ]; then
    echo "   ✓ GET на / работает"
else
    echo "   ✗ GET на / НЕ работает! Ответ: $RESPONSE"
fi
echo ""

echo "Тест 2: POST на /mqtt"
RESPONSE=$(curl -s -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}')

if [ "$RESPONSE" = "OK" ]; then
    echo "   ✓ POST на /mqtt работает! Ответ: $RESPONSE"
    MQTT_WORKS=true
else
    echo "   ✗ POST на /mqtt НЕ работает! Ответ: $RESPONSE"
    MQTT_WORKS=false
fi
echo ""

echo "Тест 3: POST на /mqtt (gate2)"
RESPONSE=$(curl -s -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate2"}')

if [ "$RESPONSE" = "OK" ]; then
    echo "   ✓ POST на /mqtt (gate2) работает! Ответ: $RESPONSE"
else
    echo "   ✗ POST на /mqtt (gate2) НЕ работает! Ответ: $RESPONSE"
    MQTT_WORKS=false
fi
echo ""

echo "========================================"
echo "Последние логи:"
echo "========================================"
sudo journalctl -u health-check.service -n 10 --no-pager
echo ""

echo "========================================"
echo "Итог:"
echo "========================================"

if [ "$MQTT_WORKS" = true ]; then
    echo "✓ ВСЁ РАБОТАЕТ!"
    echo ""
    echo "MQTT эндпоинт готов к использованию."
    echo ""
    echo "Примеры использования:"
    echo "  # Тест gate1"
    echo "  curl -X POST http://YOUR_VPS_IP:8001/mqtt \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"gate\":\"gate1\"}'"
    echo ""
    echo "  # Тест gate2"
    echo "  curl -X POST http://YOUR_VPS_IP:8001/mqtt \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"gate\":\"gate2\"}'"
else
    echo "✗ ЧТО-ТО НЕ РАБОТАЕТ!"
    echo ""
    echo "Проверьте логи выше для диагностики."
fi
