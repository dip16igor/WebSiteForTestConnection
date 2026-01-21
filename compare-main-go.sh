#!/bin/bash

# Скрипт для сравнения main.go на VPS и в рабочей директории

echo "Сравнение main.go на VPS и в рабочей директории..."
echo "========================================"
echo ""

VPS_MAIN="/tmp/health-check-deploy/main.go"
WORK_MAIN="c:/Users/dip16/Nextcloud/WebSiteForTestConnection/main.go"

echo "Проверка файла на VPS:"
if [ -f "$VPS_MAIN" ]; then
    echo "   ✓ Файл существует на VPS"
else
    echo "   ✗ Файл НЕ существует на VPS"
    exit 1
fi
echo ""

echo "1. Проверка строки 521 (должно быть 'mux := http.NewServeMux()'):"
LINE_521=$(sed -n '521p' "$VPS_MAIN")
echo "   $LINE_521"
if echo "$LINE_521" | grep -q "NewServeMux"; then
    echo "   ✓ Содержит NewServeMux"
else
    echo "   ✗ НЕ содержит NewServeMux"
fi
echo ""

echo "2. Проверка строки 528 (должно быть 'Handler:       mux,'):"
LINE_528=$(sed -n '528p' "$VPS_MAIN")
echo "   $LINE_528"
if echo "$LINE_528" | grep -q "Handler:"; then
    echo "   ✓ Содержит Handler: mux"
else
    echo "   ✗ НЕ содержит Handler: mux"
fi
echo ""

echo "3. Проверка строки 406 (должно быть 'if r.Method != http.MethodPost {'):"
LINE_406=$(sed -n '406p' "$VPS_MAIN")
echo "   $LINE_406"
if echo "$LINE_406" | grep -q "http.MethodPost"; then
    echo "   ✓ Содержит http.MethodPost"
else
    echo "   ✗ НЕ содержит http.MethodPost"
fi
echo ""

echo "========================================"
echo "Вывод:"
echo "========================================"

if echo "$LINE_521" | grep -q "NewServeMux" && \
   echo "$LINE_528" | grep -q "Handler:" && \
   echo "$LINE_406" | grep -q "http.MethodPost"; then
    echo "✓ Файл main.go на VPS содержит все исправления!"
    echo ""
    echo "Если бинарник всё ещё не работает, попробуйте:"
    echo "  cd /tmp/health-check-deploy"
    echo "  /usr/local/go/bin/go clean -cache"
    echo "  /usr/local/go/bin/go build -a -o health-check-server main.go"
    echo "  sudo cp health-check-server /etc/health-check-server/"
    echo "  sudo systemctl restart health-check.service"
else
    echo "✗ Файл main.go на VPS НЕ содержит все исправления!"
    echo ""
    echo "Нужно скопировать ОБНОВЛЁННЫЙ файл из Windows:"
    echo "  c:/Users/dip16/Nextcloud/WebSiteForTestConnection/main.go"
    echo "  в директорию:"
    echo "  /tmp/health-check-deploy/"
    echo ""
    echo "Через MobaXterm!"
fi
