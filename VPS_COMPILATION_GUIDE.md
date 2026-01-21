# Руководство по компиляции health-check-server на VPS

## Обзор

Это руководство описывает, как скомпилировать health-check-server с MQTT интеграцией на VPS под управлением Ubuntu.

## Необходимые файлы для копирования на VPS

### Минимальный набор файлов для компиляции:

```
main.go          # Исходный код приложения
go.mod           # Файл зависимостей Go
config.yaml      # Конфигурационный файл (с вашими настройками)
```

### Дополнительные файлы (опционально):

```
health-check.service  # Systemd service файл (для установки сервиса)
```

## Подготовка файлов на Windows

### Шаг 1: Подготовка директории

Создайте временную директорию для файлов, которые будут скопированы на VPS:

```cmd
mkdir C:\temp\vps-deploy
```

### Шаг 2: Копирование файлов

Скопируйте следующие файлы из директории проекта в `C:\temp\vps-deploy\`:

1. **main.go** - исходный код приложения
2. **go.mod** - файл зависимостей
3. **config.yaml** - конфигурация с вашими MQTT настройками
4. **health-check.service** - файл сервиса (опционально)

## Загрузка файлов на VPS через MobaXterm

### Способ 1: Через SFTP в MobaXterm

1. Откройте MobaXterm и подключитесь к вашему VPS
2. В левой панели найдите директорию `/tmp/`
3. Создайте новую директорию: `/tmp/health-check-deploy/`
4. Перетащите файлы из `C:\temp\vps-deploy\` в `/tmp/health-check-deploy/` в MobaXterm

### Способ 2: Через командную строку (PowerShell)

```powershell
# Перейдите в директорию с файлами
cd C:\temp\vps-deploy

# Загрузите файлы на VPS (замените user@your-vps-ip на ваши данные)
scp main.go user@your-vps-ip:/tmp/health-check-deploy/
scp go.mod user@your-vps-ip:/tmp/health-check-deploy/
scp config.yaml user@your-vps-ip:/tmp/health-check-deploy/
scp health-check.service user@your-vps-ip:/tmp/health-check-deploy/
```

## Компиляция на VPS

### Шаг 1: Проверка установки Go

Подключитесь к VPS через SSH (MobaXterm) и проверьте, установлен ли Go:

```bash
go version
```

Если Go не установлен, установите его:

```bash
# Загрузка Go 1.21
wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz

# Распаковка в /usr/local
sudo tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz

# Добавление Go в PATH (добавьте в ~/.bashrc или ~/.profile)
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# Проверка установки
go version
```

### Шаг 2: Переход в директорию с файлами

```bash
cd /tmp/health-check-deploy
```

### Шаг 3: Скачивание зависимостей

```bash
go mod download
```

Это загрузит все необходимые зависимости из go.mod:
- github.com/eclipse/paho.mqtt.golang v1.4.3
- gopkg.in/yaml.v3 v3.0.1

### Шаг 4: Компиляция бинарника

```bash
go build -o health-check-server main.go
```

Эта команда создаст исполняемый файл `health-check-server` в текущей директории.

### Шаг 5: Проверка бинарника

```bash
ls -lh health-check-server
file health-check-server
```

Вы должны увидеть что-то вроде:
```
-rwxr-xr-x 1 user user 8.5M Jan 4 14:00 health-check-server
health-check-server: ELF 64-bit LSB executable, x86-64, version 1 (SYSV)
```

## Установка на VPS

### Шаг 1: Создание директории для приложения

```bash
sudo mkdir -p /etc/health-check-server
```

### Шаг 2: Копирование бинарника

```bash
sudo cp health-check-server /etc/health-check-server/
sudo chmod +x /etc/health-check-server/health-check-server
```

### Шаг 3: Копирование конфигурации

```bash
sudo cp config.yaml /etc/health-check-server/
sudo chmod 600 /etc/health-check-server/config.yaml
```

### Шаг 4: Установка systemd сервиса

```bash
sudo cp health-check.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable health-check.service
```

### Шаг 5: Запуск сервиса

```bash
sudo systemctl start health-check.service
```

### Шаг 6: Проверка статуса сервиса

```bash
sudo systemctl status health-check.service
```

## Тестирование

### Тест 1: Проверка health check эндпоинта

```bash
curl http://localhost:8001/
```

Ожидаемый ответ:
```json
{"status":"ok","timestamp":"2024-01-04T14:00:00Z"}
```

### Тест 2: Проверка MQTT эндпоинта (gate1)

```bash
curl -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}'
```

Ожидаемый ответ:
```json
{"status":"success","message":"MQTT message published","gate":"gate1","topic":"GateControl/Gate","payload":"179226315200"}
```

### Тест 3: Проверка MQTT эндпоинта (gate2)

```bash
curl -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate2"}'
```

Ожидаемый ответ:
```json
{"status":"success","message":"MQTT message published","gate":"gate2","topic":"GateControl/Gate","payload":"279226315200"}
```

## Просмотр логов

### Просмотр логов сервиса

```bash
sudo journalctl -u health-check.service -f
```

### Просмотр последних 50 строк логов

```bash
sudo journalctl -u health-check.service -n 50
```

### Просмотр логов с момента последнего запуска

```bash
sudo journalctl -u health-check.service --since today
```

## Устранение проблем

### Проблема: Go не установлен

**Решение:** Установите Go, как описано в "Шаг 1: Проверка установки Go"

### Проблема: Ошибка при go mod download

**Решение:** Проверьте подключение к интернету и попробуйте снова:

```bash
go clean -modcache
go mod download
```

### Проблема: Ошибка компиляции

**Решение:** Проверьте версию Go (должна быть 1.19 или выше):

```bash
go version
```

Если версия старая, обновите Go до последней версии.

### Проблема: Сервис не запускается

**Решение:** Проверьте логи:

```bash
sudo journalctl -u health-check.service -n 50 --no-pager
```

Общие причины:
- Отсутствует файл config.yaml
- Неверные права доступа к файлам
- MQTT брокер недоступен

### Проблема: MQTT брокер недоступен

**Решение:** Проверьте подключение к MQTT брокеру:

```bash
# Проверка соединения с брокером
telnet 78.29.40.170 1883

# Или с помощью nc
nc -zv 78.29.40.170 1883
```

Если соединение не устанавливается, проверьте настройки firewall на VPS.

## Полезные команды

### Перезапуск сервиса

```bash
sudo systemctl restart health-check.service
```

### Остановка сервиса

```bash
sudo systemctl stop health-check.service
```

### Отключение автозапуска

```bash
sudo systemctl disable health-check.service
```

### Обновление бинарника без остановки сервиса

```bash
# 1. Скомпилируйте новый бинарник
go build -o health-check-server main.go

# 2. Скопируйте новый бинарник
sudo cp health-check-server /etc/health-check-server/

# 3. Перезапустите сервис
sudo systemctl restart health-check.service
```

## Резюме

Для компиляции на VPS вам понадобятся только **3 файла**:

1. ✅ **main.go** - исходный код
2. ✅ **go.mod** - зависимости
3. ✅ **config.yaml** - конфигурация

Опционально:
- ✅ **health-check.service** - файл сервиса (для установки systemd сервиса)

Все остальные файлы (README.md, deploy-vps.sh и т.д.) не обязательны для компиляции и работы приложения.
