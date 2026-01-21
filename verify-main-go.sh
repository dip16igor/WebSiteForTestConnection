#!/bin/bash

# Скрипт для проверки содержимого main.go на VPS

echo "Проверка содержимого main.go на VPS..."
echo "========================================"
echo ""

MAIN_GO="/tmp/health-check-deploy/main.go"

if [ ! -f "$MAIN_GO" ]; then
    echo "ОШИБКА: Файл $MAIN_GO не найден!"
    exit 1
fi

echo "1. Проверка строки 400 (должно быть http.MethodPost):"
sed -n '400p' "$MAIN_GO"
echo ""

echo "2. Проверка строки 188 (должен быть комментарий про опциональные username/password):"
sed -n '188p' "$MAIN_GO"
echo ""

echo "3. Проверка строки 404 (должно быть логирование 'MQTT publish: Method not allowed'):"
sed -n '404p' "$MAIN_GO"
echo ""

echo "========================================"
echo "Анализ:"
echo "========================================"

if grep -q "http.MethodPost" "$MAIN_GO"; then
    echo "✓ Файл содержит http.MethodPost"
else
    echo "✗ Файл НЕ содержит http.MethodPost (старая версия!)"
fi

if grep -q "Username and password are optional" "$MAIN_GO"; then
    echo "✓ Файл содержит комментарий про опциональные username/password"
else
    echo "✗ Файл НЕ содержит комментарий (старая версия!)"
fi

if grep -q "MQTT publish: Method not allowed" "$MAIN_GO"; then
    echo "✓ Файл содержит правильное логирование"
else
    echo "✗ Файл содержит старое логирование"
fi

echo ""
echo "Если все проверки показывают '✗', нужно скопировать ОБНОВЛЁННЫЙ файл main.go с Windows на VPS!"
