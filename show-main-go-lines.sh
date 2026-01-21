#!/bin/bash

# Скрипт для показа точных строк из main.go на VPS

echo "Показ точных строк из main.go на VPS..."
echo "========================================"
echo ""

MAIN_GO="/tmp/health-check-deploy/main.go"

if [ ! -f "$MAIN_GO" ]; then
    echo "ОШИБКА: Файл $MAIN_GO не найден!"
    exit 1
fi

echo "Строки 343-347 (проверка пути):"
sed -n '343,347p' "$MAIN_GO"
echo ""

echo "Строка 400 (заголовок функции):"
sed -n '400p' "$MAIN_GO"
echo ""

echo "Строка 405 (проверка метода):"
sed -n '405p' "$MAIN_GO"
echo ""

echo "Строка 406 (проверка метода):"
sed -n '406p' "$MAIN_GO"
echo ""

echo "Строка 407 (логирование):"
sed -n '407p' "$MAIN_GO"
echo ""

echo "========================================"
echo "Анализ:"
echo "========================================"

# Проверка строки 344
LINE_344=$(sed -n '344p' "$MAIN_GO")
if echo "$LINE_344" | grep -q "if r.URL.Path"; then
    echo "✓ Строка 344 содержит проверку r.URL.Path"
else
    echo "✗ Строка 344 НЕ содержит проверку r.URL.Path"
fi

# Проверка строки 345
LINE_345=$(sed -n '345p' "$MAIN_GO")
if echo "$LINE_345" | grep -q '!= "/"'; then
    echo "✓ Строка 345 содержит проверку пути"
else
    echo "✗ Строка 345 НЕ содержит проверку пути"
fi

# Проверка строки 406
LINE_406=$(sed -n '406p' "$MAIN_GO")
if echo "$LINE_406" | grep -q "http.MethodPost"; then
    echo "✓ Строка 406 содержит http.MethodPost"
else
    echo "✗ Строка 406 НЕ содержит http.MethodPost"
fi
