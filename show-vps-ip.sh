#!/bin/bash

# Скрипт для показа IP-адреса VPS

echo "Информация о VPS..."
echo "========================================"
echo ""

echo "1. IP-адреса VPS:"
echo ""

# Показываем все IP-адреса
echo "IPv4 адреса:"
hostname -I | awk '{print $3}'
echo ""

echo "IPv6 адреса:"
hostname -I | awk '{print $3}'
echo ""

echo "2. Проверка, что сервис слушает порт 8001:"
if sudo netstat -tlnp | grep 8001 > /dev/null; then
    echo "   ✓ Порт 8001 слушается"
    sudo netstat -tlnp | grep 8001
else
    echo "   ✗ Порт 8001 НЕ слушается"
fi
echo ""

echo "3. Статус сервиса:"
systemctl status health-check.service --no-pager | head -10
echo ""

echo "========================================"
echo "Примеры для тестирования извне:"
echo "========================================"
echo ""

echo "Тест health check эндпоинта:"
echo "  curl http://<IP_VPS>:8001/"
echo ""

echo "Тест MQTT эндпоинта (gate1):"
echo "  curl -X POST http://<IP_VPS>:8001/mqtt \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"gate\":\"gate1\"}'"
echo ""

echo "Тест MQTT эндпоинта (gate2):"
echo "  curl -X POST http://<IP_VPS>:8001/mqtt \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"gate\":\"gate2\"}'"
echo ""

echo "========================================"
echo "Примечание:"
echo "========================================"
echo "Если VPS за firewall/NAT, используйте публичный IP-адрес."
echo "Для тестирования с Windows:"
echo "  curl -X POST http://<IP_VPS>:8001/mqtt -H \"Content-Type: application/json\" -d \"{\\\"gate\\\":\\\"gate1\\\"}\""
echo ""
echo "Для мониторинга MQTT сообщений:"
echo "  mosquitto_sub -h <MQTT_BROKER_IP> -t \"GateControl/Gate\" -v"
echo ""
