#!/bin/bash

# Простой скрипт для ручного обновления health-check-server
# Запускать на VPS как root или с sudo

set -e

echo "=== Ручное обновление Health Check Server ==="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода успешного сообщения
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Функция для вывода сообщения об ошибке
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Функция для вывода предупреждения
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Функция для вывода информационного сообщения
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Проверка, что запущен как root
if [[ $EUID -ne 0 ]]; then
    print_error "Этот скрипт должен быть запущен как root (используйте sudo)"
    exit 1
fi

# Переменные конфигурации
BINARY_NAME="health-check-server"
CONFIG_DIR="/etc/health-check-server"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/health-check.service"
WORK_DIR="/tmp/health-check-update"

# Шаг 1: Создание резервной копии текущего binary
echo "Шаг 1: Создание резервной копии..."
if [ -f /usr/local/bin/$BINARY_NAME ]; then
    BACKUP_FILE="/usr/local/bin/$BINARY_NAME.backup.$(date +%Y%m%d_%H%M%S)"
    cp /usr/local/bin/$BINARY_NAME "$BACKUP_FILE"
    print_success "Резервная копия создана: $BACKUP_FILE"
else
    print_warning "Существующий binary не найден, создание резервной копии пропущено"
fi
echo ""

# Шаг 2: Создание рабочей директории
echo "Шаг 2: Создание рабочей директории..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
print_success "Рабочая директория создана"
echo ""

# Шаг 3: Проверка наличия main.go
echo "Шаг 3: Проверка наличия main.go..."
if [ -f "/root/main.go" ]; then
    print_success "main.go найден в /root/"
    cp /root/main.go .
elif [ -f "main.go" ]; then
    print_success "main.go найден в текущей директории"
else
    print_error "main.go не найден! Пожалуйста, скопируйте main.go в /root/ или в текущую директорию"
    exit 1
fi
echo ""

# Шаг 4: Проверка установки Go
echo "Шаг 4: Проверка установки Go..."
if ! command -v go &> /dev/null; then
    print_error "Go не установлен. Установка..."
    apt update && apt install -y golang-go
fi
GO_VERSION=$(go version | awk '{print $3}')
print_success "Go установлен: $GO_VERSION"
echo ""

# Шаг 5: Компиляция
echo "Шаг 5: Компиляция health-check-server..."
if go build -o $BINARY_NAME main.go; then
    print_success "Компиляция успешна"
else
    print_error "Компиляция не удалась"
    exit 1
fi
echo ""

# Шаг 6: Копирование binary
echo "Шаг 6: Копирование нового binary..."
cp $BINARY_NAME /usr/local/bin/
chmod +x /usr/local/bin/$BINARY_NAME
chown root:healthcheck /usr/local/bin/$BINARY_NAME
print_success "Binary скопирован и права установлены"
echo ""

# Шаг 7: Обновление конфигурации
echo "Шаг 7: Обновление конфигурации..."
if [ -f "/root/config.yaml" ]; then
    print_info "Найден config.yaml в /root/"
    cp /root/config.yaml "$CONFIG_FILE"
    print_success "Конфигурация скопирована"
elif [ -f "config.yaml" ]; then
    print_info "Найден config.yaml в текущей директории"
    cp config.yaml "$CONFIG_FILE"
    print_success "Конфигурация скопирована"
else
    print_warning "config.yaml не найден, используется существующая конфигурация"
fi

chmod 600 "$CONFIG_FILE"
chown healthcheck:healthcheck "$CONFIG_FILE"
echo ""

# Шаг 8: Перезапуск сервиса
echo "Шаг 8: Перезапуск health check service..."
systemctl restart health-check.service
sleep 3
echo ""

# Шаг 9: Проверка статуса сервиса
echo "Шаг 9: Проверка статуса сервиса..."
if systemctl is-active --quiet health-check.service; then
    print_success "Health check сервис запущен"
else
    print_error "Health check сервис не запустился"
    echo ""
    echo "Проверка логов для ошибок:"
    journalctl -u health-check.service -n 20 --no-pager
    exit 1
fi
echo ""

# Шаг 10: Тестирование health check endpoint
echo "Шаг 10: Тестирование health check endpoint..."
if curl -f --max-time 5 http://localhost:8001 > /dev/null 2>&1; then
    print_success "Health check endpoint отвечает корректно"
else
    print_error "Health check endpoint не отвечает"
    echo ""
    echo "Проверка логов:"
    journalctl -u health-check.service -n 20 --no-pager
    exit 1
fi
echo ""

# Шаг 11: Тестирование MQTT publish endpoint
echo "Шаг 11: Тестирование MQTT publish endpoint..."
echo "Тестирование gate1..."
if curl -f "http://localhost:8001/mqtt?gate=gate1" --max-time 5 > /dev/null 2>&1; then
    print_success "MQTT publish для gate1 работает"
else
    print_warning "MQTT publish для gate1 не удался (может быть нормально, если MQTT брокер не настроен)"
fi

echo "Тестирование gate2..."
if curl -f "http://localhost:8001/mqtt?gate=gate2" --max-time 5 > /dev/null 2>&1; then
    print_success "MQTT publish для gate2 работает"
else
    print_warning "MQTT publish для gate2 не удался (может быть нормально, если MQTT брокер не настроен)"
fi
echo ""

# Шаг 12: Тестирование action endpoint
echo "Шаг 12: Тестирование action endpoint (второй MQTT брокер)..."
if curl -f "http://localhost:8001/action?action=vol+" --max-time 5 > /dev/null 2>&1; then
    print_success "Action endpoint для vol+ работает"
else
    print_warning "Action endpoint для vol+ не удался (может быть нормально, если второй MQTT брокер не настроен)"
fi

if curl -f "http://localhost:8001/action?action=vol-" --max-time 5 > /dev/null 2>&1; then
    print_success "Action endpoint для vol- работает"
else
    print_warning "Action endpoint для vol- не удался (может быть нормально, если второй MQTT брокер не настроен)"
fi
echo ""

# Шаг 13: Отображение последних логов
echo "Шаг 13: Отображение последних логов..."
echo "Последние логи health check server:"
journalctl -u health-check.service -n 15 --no-pager
echo ""

# Шаг 14: Отображение информации о сервисе
echo "Шаг 14: Информация о сервисе..."
echo ""
systemctl status health-check.service --no-pager
echo ""

# Очистка
echo "Очистка временных файлов..."
cd /
rm -rf "$WORK_DIR"
print_success "Временные файлы удалены"
echo ""

echo "=== Обновление завершено ==="
echo ""
echo "Health check server запущен на порту 8001"
echo ""
echo "Полезные команды:"
echo "  Проверить статус: systemctl status health-check.service"
echo "  Просмотреть логи: journalctl -u health-check.service -f"
echo "  Перезапустить сервис: systemctl restart health-check.service"
echo "  Остановить сервис: systemctl stop health-check.service"
echo "  Редактировать конфиг: nano /etc/health-check-server/config.yaml"
echo ""
echo "Конфигурация: $CONFIG_FILE"
echo "Binary: /usr/local/bin/$BINARY_NAME"
echo "Сервис: $SERVICE_FILE"
echo ""
echo "Новые endpoints:"
echo "  curl \"http://<IP_VPS>:8001/action?action=vol+\""
echo "  curl \"http://<IP_VPS>:8001/action?action=vol-\""
echo ""
echo "Второй MQTT брокер:"
echo "  Адрес: tcp://46.8.233.146:1883"
echo "  Логин: dip16"
echo "  Пароль: nirvana7"
echo "  Топик: Home/WebRadio2/Action"
