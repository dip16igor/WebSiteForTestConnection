#!/bin/bash

# Скрипт для проверки всех ключевых строк в бинарнике

echo "Проверка всех ключевых строк в бинарнике..."
echo "========================================"
echo ""

BINARY="/etc/health-check-server/health-check-server"

echo "1. Проверка строки 'Only allow POST requests':"
if strings "$BINARY" | grep -q "Only allow POST requests"; then
    echo "   ✓ Найдено"
else
    echo "   ✗ НЕ найдено"
fi
echo ""

echo "2. Проверка строки 'MQTT publish: Method not allowed':"
if strings "$BINARY" | grep -q "MQTT publish: Method not allowed"; then
    echo "   ✓ Найдено"
else
    echo "   ✗ НЕ найдено"
fi
echo ""

echo "3. Проверка строки 'Only handle root path':"
if strings "$BINARY" | grep -q "Only handle root path"; then
    echo "   ✓ Найдено"
else
    echo "   ✗ НЕ найдено"
fi
echo ""

echo "4. Проверка строки 'NewServeMux':"
if strings "$BINARY" | grep -q "NewServeMux"; then
    echo "   ✓ Найдено"
else
    echo "   ✗ НЕ найдено"
fi
echo ""

echo "5. Проверка строки 'HandleFunc':"
if strings "$BINARY" | grep -q "HandleFunc"; then
    echo "   ✓ Найдено"
else
    echo "   ✗ НЕ найдено"
fi
echo ""

echo "========================================"
echo "Анализ:"
echo "========================================"

# Проверка, что бинарник содержит хотя бы одну из строк
if strings "$BINARY" | grep -q "Only allow POST requests\|MQTT publish: Method not allowed\|Only handle root path\|NewServeMux"; then
    echo "✓ Бинарник содержит исправления"
else
    echo "✗ Бинарник НЕ содержит исправления (старый!)"
    echo ""
    echo "Нужно перекомпилировать:"
    echo "  cd /tmp/health-check-deploy"
    echo "  /usr/local/go/bin/go build -o health-check-server main.go"
    echo "  sudo cp health-check-server $BINARY"
    echo "  sudo systemctl restart health-check.service"
fi
