#!/bin/bash

# Скрипт для проверки запущенных процессов

echo "Проверка запущенных процессов health-check-server..."
echo "========================================"
echo ""

echo "1. Все процессы health-check-server:"
ps aux | grep health-check-server | grep -v grep
echo ""

echo "2. PID процесса:"
PID=$(pgrep -f health-check-server)
if [ -n "$PID" ]; then
    echo "   PID: $PID"
    echo "   Время запуска:"
    ps -p $PID -o lstart=
    echo "   Команда:"
    ps -p $PID -o command=
else
    echo "   Процесс не найден!"
fi
echo ""

echo "3. Проверка порта 8001:"
sudo netstat -tlnp | grep 8001
echo ""

echo "4. Проверка systemd сервиса:"
systemctl status health-check.service --no-pager | head -15
echo ""

echo "========================================"
echo "Анализ:"
echo "========================================"

# Проверка, есть ли несколько процессов
PROC_COUNT=$(pgrep -f health-check-server | wc -l)
if [ "$PROC_COUNT" -gt 1 ]; then
    echo "✗ Запущено несколько процессов ($PROC_COUNT)! Нужно убить старые."
    echo ""
    echo "Команда для убийства всех процессов:"
    echo "  sudo pkill -f health-check-server"
    echo "  sudo systemctl restart health-check.service"
else
    echo "✓ Запущен только один процесс"
fi

# Проверка времени запуска
if [ -n "$PID" ]; then
    START_TIME=$(ps -p $PID -o lstart=)
    echo "✓ Процесс запущен: $START_TIME"
fi
