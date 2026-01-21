#!/bin/bash

# Скрипт для полной перезагрузки сервиса

echo "Полная перезагрузка health-check-server..."
echo "========================================"
echo ""

echo "1. Остановка сервиса:"
sudo systemctl stop health-check.service
echo ""

echo "2. Проверка, что процесс остановлен:"
sleep 2
if pgrep -f health-check-server > /dev/null; then
    echo "   ✗ Процесс всё ещё работает! Убиваю..."
    sudo pkill -9 -f health-check-server
    sleep 1
else
    echo "   ✓ Процесс остановлен"
fi
echo ""

echo "3. Проверка порта 8001:"
if sudo netstat -tlnp | grep 8001 > /dev/null; then
    echo "   ✗ Порт 8001 всё ещё занят!"
    echo "   Жду освобождения порта..."
    sleep 3
else
    echo "   ✓ Порт 8001 свободен"
fi
echo ""

echo "4. Запуск сервиса:"
sudo systemctl start health-check.service
echo ""

echo "5. Проверка статуса сервиса:"
sleep 2
if systemctl is-active --quiet health-check.service; then
    echo "   ✓ Сервис запущен"
else
    echo "   ✗ Сервис НЕ запущен!"
    echo ""
    echo "   Проверьте логи:"
    echo "   sudo journalctl -u health-check.service -n 20"
    exit 1
fi
echo ""

echo "6. Проверка процесса:"
PID=$(pgrep -f health-check-server)
if [ -n "$PID" ]; then
    echo "   ✓ Процесс запущен (PID: $PID)"
else
    echo "   ✗ Процесс НЕ запущен!"
    exit 1
fi
echo ""

echo "========================================"
echo "Тестирование после перезагрузки:"
echo "========================================"

echo "Тест POST на /mqtt:"
RESPONSE=$(curl -s -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}')

if [ "$RESPONSE" = "OK" ]; then
    echo "   ✓ MQTT эндпоинт работает! Ответ: $RESPONSE"
else
    echo "   ✗ MQTT эндпоинт НЕ работает! Ответ: $RESPONSE"
fi
echo ""

echo "Последние логи:"
sudo journalctl -u health-check.service -n 5 --no-pager
