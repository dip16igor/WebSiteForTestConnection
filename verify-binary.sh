#!/bin/bash

# Скрипт для проверки бинарника на VPS

echo "Проверка бинарника health-check-server..."
echo "========================================"
echo ""

BINARY="/etc/health-check-server/health-check-server"

if [ ! -f "$BINARY" ]; then
    echo "ОШИБКА: Бинарник $BINARY не найден!"
    exit 1
fi

echo "1. Проверка времени модификации бинарника:"
ls -lh "$BINARY"
echo ""

echo "2. Поиск строк в бинарнике:"
echo ""

if strings "$BINARY" | grep -q "MQTT publish: Method not allowed"; then
    echo "✓ Бинарник содержит 'MQTT publish: Method not allowed' (новая версия)"
else
    echo "✗ Бинарник НЕ содержит 'MQTT publish: Method not allowed' (старая версия!)"
fi

if strings "$BINARY" | grep -q "Only allow POST requests"; then
    echo "✓ Бинарник содержит 'Only allow POST requests' (новая версия)"
else
    echo "✗ Бинарник НЕ содержит 'Only allow POST requests' (старая версия!)"
fi

if strings "$BINARY" | grep -q "Username and password are optional"; then
    echo "✓ Бинарник содержит комментарий про опциональные username/password (новая версия)"
else
    echo "✗ Бинарник НЕ содержит комментарий (старая версия!)"
fi

echo ""
echo "========================================"
echo "Вывод:"
echo "========================================"

if strings "$BINARY" | grep -q "MQTT publish: Method not allowed"; then
    echo "✓ Бинарник скомпилирован из обновлённого main.go"
else
    echo "✗ Бинарник скомпилирован из СТАРОГО main.go!"
    echo ""
    echo "Нужно перекомпилировать:"
    echo "  cd /tmp/health-check-deploy"
    echo "  /usr/local/go/bin/go build -o health-check-server main.go"
    echo "  sudo cp health-check-server $BINARY"
    echo "  sudo systemctl restart health-check.service"
fi
