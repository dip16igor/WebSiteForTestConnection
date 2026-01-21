#!/bin/bash

# Скрипт для автоматической компиляции health-check-server на VPS
# Использование: sudo bash build-on-vps.sh

set -e  # Прерывание при ошибках

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    log_error "Пожалуйста, запустите скрипт с правами root (sudo)"
    exit 1
fi

# Директория с исходными файлами
SOURCE_DIR="/tmp/health-check-deploy"
INSTALL_DIR="/etc/health-check-server"

log_info "Начинаю компиляцию health-check-server на VPS..."

# Шаг 1: Проверка наличия исходных файлов
log_info "Проверка исходных файлов..."
if [ ! -f "$SOURCE_DIR/main.go" ]; then
    log_error "Файл main.go не найден в $SOURCE_DIR"
    log_info "Пожалуйста, скопируйте следующие файлы в $SOURCE_DIR:"
    log_info "  - main.go"
    log_info "  - go.mod"
    log_info "  - config.yaml"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/go.mod" ]; then
    log_error "Файл go.mod не найден в $SOURCE_DIR"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/config.yaml" ]; then
    log_error "Файл config.yaml не найден в $SOURCE_DIR"
    exit 1
fi

log_info "✓ Все исходные файлы найдены"

# Шаг 2: Проверка установки Go
log_info "Проверка установки Go..."

# Проверка в стандартных locations
GO_PATHS=(
    "/usr/local/go/bin/go"
    "/usr/bin/go"
    "/usr/local/bin/go"
    "$HOME/go/bin/go"
)

GO_FOUND=false
for go_path in "${GO_PATHS[@]}"; do
    if [ -x "$go_path" ]; then
        log_info "✓ Go найден: $go_path"
        export PATH=$PATH:$(dirname "$go_path")
        GO_FOUND=true
        break
    fi
done

# Если не найден, пробуем команду go в PATH
if [ "$GO_FOUND" = false ]; then
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | awk '{print $3}')
        log_info "✓ Go уже установлен: $GO_VERSION"
        GO_FOUND=true
    fi
fi

if [ "$GO_FOUND" = false ]; then
    log_warn "Go не найден в системе. Начинаю установку..."
    
    # Определение архитектуры
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        GO_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        GO_ARCH="arm64"
    else
        log_error "Неизвестная архитектура: $ARCH"
        exit 1
    fi
    
    # Загрузка Go 1.21.6
    log_info "Загрузка Go 1.21.6 для $GO_ARCH..."
    cd /tmp
    wget -q https://go.dev/dl/go1.21.6.linux-${GO_ARCH}.tar.gz
    
    # Распаковка
    log_info "Распаковка Go..."
    tar -C /usr/local -xzf go1.21.6.linux-${GO_ARCH}.tar.gz
    
    # Настройка PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin
    
    # Очистка
    rm go1.21.6.linux-${GO_ARCH}.tar.gz
    
    log_info "✓ Go 1.21.6 установлен"
else
    GO_VERSION=$(go version | awk '{print $3}')
    log_info "✓ Go уже установлен: $GO_VERSION"
fi

# Шаг 3: Переход в директорию с исходными файлами
log_info "Переход в директорию с исходными файлами..."
cd "$SOURCE_DIR"

# Шаг 4: Скачивание зависимостей
log_info "Скачивание зависимостей..."
go mod download
log_info "✓ Зависимости загружены"

# Шаг 4.5: Генерация go.sum
log_info "Генерация go.sum..."
go mod tidy
log_info "✓ go.sum сгенерирован"

# Шаг 5: Компиляция бинарника
log_info "Компиляция бинарника..."
go build -o health-check-server main.go
log_info "✓ Бинарник скомпилирован"

# Шаг 6: Проверка бинарника
log_info "Проверка бинарника..."
if [ ! -f "health-check-server" ]; then
    log_error "Бинарник не был создан"
    exit 1
fi

BINARY_SIZE=$(ls -lh health-check-server | awk '{print $5}')
log_info "✓ Бинарник создан: размер $BINARY_SIZE"

# Шаг 7: Создание директории установки
log_info "Создание директории установки..."
mkdir -p "$INSTALL_DIR"
log_info "✓ Директория $INSTALL_DIR создана"

# Шаг 8: Создание резервной копии существующего бинарника
if [ -f "$INSTALL_DIR/health-check-server" ]; then
    log_info "Создание резервной копии существующего бинарника..."
    cp "$INSTALL_DIR/health-check-server" "$INSTALL_DIR/health-check-server.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "✓ Резервная копия создана"
fi

# Шаг 9: Копирование бинарника
log_info "Копирование бинарника..."
cp health-check-server "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/health-check-server"
log_info "✓ Бинарник скопирован"

# Шаг 10: Копирование конфигурации
log_info "Копирование конфигурации..."
if [ -f "$INSTALL_DIR/config.yaml" ]; then
    log_info "Создание резервной копии существующей конфигурации..."
    cp "$INSTALL_DIR/config.yaml" "$INSTALL_DIR/config.yaml.backup.$(date +%Y%m%d_%H%M%S)"
fi

cp config.yaml "$INSTALL_DIR/"
chmod 600 "$INSTALL_DIR/config.yaml"
log_info "✓ Конфигурация скопирована"

# Шаг 11: Установка systemd сервиса (если файл существует)
if [ -f "$SOURCE_DIR/health-check.service" ]; then
    log_info "Установка systemd сервиса..."
    cp "$SOURCE_DIR/health-check.service" /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable health-check.service
    log_info "✓ Systemd сервис установлен"
else
    log_warn "Файл health-check.service не найден, пропускаю установку сервиса"
fi

# Шаг 12: Перезапуск сервиса
log_info "Перезапуск сервиса..."
if systemctl is-active --quiet health-check.service; then
    systemctl restart health-check.service
    log_info "✓ Сервис перезапущен"
else
    systemctl start health-check.service
    log_info "✓ Сервис запущен"
fi

# Шаг 13: Проверка статуса сервиса
log_info "Проверка статуса сервиса..."
sleep 2
if systemctl is-active --quiet health-check.service; then
    log_info "✓ Сервис работает корректно"
else
    log_error "Сервис не запустился!"
    log_info "Проверьте логи: journalctl -u health-check.service -n 50"
    exit 1
fi

# Шаг 14: Тестирование health check эндпоинта
log_info "Тестирование health check эндпоинта..."
sleep 1
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8001/ || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    log_info "✓ Health check эндпоинт работает (HTTP 200)"
else
    log_warn "Health check эндпоинт вернул код $HTTP_CODE"
fi

# Шаг 15: Тестирование MQTT эндпоинта
log_info "Тестирование MQTT эндпоинта..."
sleep 1
MQTT_RESPONSE=$(curl -s -X POST http://localhost:8001/mqtt \
    -H "Content-Type: application/json" \
    -d '{"gate":"gate1"}' || echo '{"error":"request failed"}')

if echo "$MQTT_RESPONSE" | grep -q "success"; then
    log_info "✓ MQTT эндпоинт работает"
else
    log_warn "MQTT эндпоинт может не работать корректно"
    log_info "Ответ: $MQTT_RESPONSE"
fi

# Шаг 16: Отображение логов
log_info "Последние логи сервиса:"
echo ""
journalctl -u health-check.service -n 20 --no-pager

# Завершение
echo ""
log_info "========================================"
log_info "Компиляция и установка завершены успешно!"
log_info "========================================"
echo ""
log_info "Полезные команды:"
echo "  - Статус сервиса: systemctl status health-check.service"
echo "  - Логи сервиса: journalctl -u health-check.service -f"
echo "  - Перезапуск: systemctl restart health-check.service"
echo "  - Остановка: systemctl stop health-check.service"
echo ""
log_info "Тестирование эндпоинтов:"
echo "  - Health check: curl http://localhost:8001/"
echo "  - MQTT (gate1): curl -X POST http://localhost:8001/mqtt -H 'Content-Type: application/json' -d '{\"gate\":\"gate1\"}'"
echo "  - MQTT (gate2): curl -X POST http://localhost:8001/mqtt -H 'Content-Type: application/json' -d '{\"gate\":\"gate2\"}'"
echo ""
