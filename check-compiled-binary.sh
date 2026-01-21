#!/bin/bash

# Скрипт для проверки бинарника после перекомпиляции

echo "Проверка бинарника после перекомпиляции..."
echo "========================================"
echo ""

BINARY="/tmp/health-check-deploy/health-check-server"

if [ ! -f "$BINARY" ]; then
    echo "ОШИБКА: Бинарник $BINARY не найден!"
    exit 1
fi

echo "1. Время модификации бинарника:"
ls -lh "$BINARY"
echo ""

echo "2. Поиск исправлений в бинарнике:"
echo ""

if strings "$BINARY" | grep -q "Only handle root path"; then
    echo "✓ Бинарник содержит 'Only handle root path' (исправление маршрутизации)"
else
    echo "✗ Бинарник НЕ содержит 'Only handle root path' (старая версия!)"
fi

if strings "$BINARY" | grep -q "MQTT publish: Method not allowed"; then
    echo "✓ Бинарник содержит 'MQTT publish: Method not allowed'"
else
    echo "✗ Бинарник НЕ содержит 'MQTT publish: Method not allowed'"
fi

if strings "$BINARY" | grep -q "Only allow POST requests"; then
    echo "✓ Бинарник содержит 'Only allow POST requests'"
else
    echo "✗ Бинарник НЕ содержит 'Only allow POST requests'"
fi

echo ""
echo "========================================"
echo "Вывод:"
echo "========================================"

if strings "$BINARY" | grep -q "Only handle root path"; then
    echo "✓ Бинарник скомпилирован с исправлением маршрутизации"
else
    echo "✗ Бинарник скомпилирован БЕЗ исправления маршрутизации!"
    echo ""
    echo "Нужно проверить, что main.go на VPS содержит исправления:"
    echo "  cd /tmp/health-check-deploy"
    echo "  bash verify-main-go.sh"
fi
