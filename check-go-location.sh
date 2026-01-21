#!/bin/bash

# Скрипт для поиска установки Go на VPS

echo "Поиск установки Go на VPS..."
echo "================================"

# Проверка команды go в PATH
echo ""
echo "1. Проверка команды 'go' в PATH:"
if command -v go &> /dev/null; then
    GO_PATH=$(command -v go)
    echo "   ✓ Go найден: $GO_PATH"
    echo "   Версия: $(go version)"
else
    echo "   ✗ Команда 'go' не найдена в PATH"
fi

# Проверка стандартных locations
echo ""
echo "2. Проверка стандартных директорий:"
LOCATIONS=(
    "/usr/local/go/bin/go"
    "/usr/bin/go"
    "/usr/local/bin/go"
    "/opt/go/bin/go"
    "/home/$USER/go/bin/go"
    "/root/go/bin/go"
)

FOUND=false
for loc in "${LOCATIONS[@]}"; do
    if [ -x "$loc" ]; then
        echo "   ✓ Go найден: $loc"
        echo "   Версия: $($loc version)"
        FOUND=true
    fi
done

if [ "$FOUND" = false ]; then
    echo "   ✗ Go не найден в стандартных директориях"
fi

# Поиск файлов go
echo ""
echo "3. Поиск файлов 'go' в системе:"
find /usr -name "go" -type f -executable 2>/dev/null | head -5

# Проверка переменной PATH
echo ""
echo "4. Текущая переменная PATH:"
echo "$PATH" | tr ':' '\n' | nl

# Проверка как обычный пользователь
echo ""
echo "5. Проверка как обычный пользователь:"
if [ "$EUID" -eq 0 ]; then
    echo "   Вы запускаете как root"
    echo "   Попробуйте переключиться на обычного пользователя:"
    echo "   su - $USER -c 'which go && go version'"
else
    echo "   Вы запускаете как обычный пользователь: $USER"
    echo "   which go: $(which go 2>/dev/null || echo 'не найден')"
    echo "   go version: $(go version 2>/dev/null || echo 'не доступен')"
fi

# Рекомендации
echo ""
echo "================================"
echo "Рекомендации:"
echo "================================"
echo ""

if command -v go &> /dev/null; then
    echo "✓ Go установлен и доступен"
    echo "  Вы можете использовать команду: go version"
else
    echo "✗ Go не найден в PATH"
    echo ""
    echo "Если Go установлен, но не в PATH, добавьте его:"
    echo "  echo 'export PATH=\$PATH:/путь/к/go/bin' >> ~/.bashrc"
    echo "  source ~/.bashrc"
    echo ""
    echo "Для root пользователя:"
    echo "  echo 'export PATH=\$PATH:/путь/к/go/bin' >> /etc/profile"
fi

echo ""
echo "Для компиляции health-check-server:"
echo "  cd /tmp/health-check-deploy"
echo "  go mod tidy"
echo "  go build -o health-check-server main.go"
