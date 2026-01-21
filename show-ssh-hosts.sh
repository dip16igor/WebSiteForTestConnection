#!/bin/bash

# Скрипт для показа доступных SSH хостов

echo "Доступные SSH хосты..."
echo "========================================"
echo ""

echo "1. Файл ~/.ssh/config:"
if [ -f "$HOME/.ssh/config" ]; then
    echo "Содержимое:"
    cat "$HOME/.ssh/config"
else
    echo "   Файл не существует"
fi
echo ""

echo "2. Файл ~/.ssh/known_hosts:"
if [ -f "$HOME/.ssh/known_hosts" ]; then
    echo "Известные хосты:"
    cat "$HOME/.ssh/known_hosts"
else
    echo "   Файл не существует"
fi
echo ""

echo "========================================"
echo "Примеры использования:"
echo "========================================"
echo ""
echo "Для подключения к VPS:"
echo "  ssh dip16@<IP_VPS>"
echo ""
echo "Для копирования файлов с Windows:"
echo "  scp main.go dip16@<IP_VPS>:/tmp/health-check-deploy/"
echo "  scp config.yaml dip16@<IP_VPS>:/tmp/health-check-deploy/"
echo ""
echo "Для выполнения команд на VPS:"
echo "  ssh dip16@<IP_VPS> 'cd /tmp/health-check-deploy && bash deploy-mux-handle-fix.sh'"
echo ""
