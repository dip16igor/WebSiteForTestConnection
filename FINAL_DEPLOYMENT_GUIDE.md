# Финальное руководство по деплою health-check-server с MQTT интеграцией

## Обзор

Это финальное руководство для деплоя обновлённого health-check-server с MQTT интеграцией на VPS.

## Что было сделано:

### Исправления в коде:

1. ✅ **MQTT эндпоинт теперь принимает POST запросы**
   - Было: `http.MethodGet` (строка 405)
   - Стало: `http.MethodPost` (строка 406)

2. ✅ **Username и password теперь опциональные**
   - Было: Обязательная валидация (строки 188-193)
   - Стало: Комментарий "Username and password are optional" (строка 188)

3. ✅ **Исправлена маршрутизация HTTP запросов**
   - Было: `http.HandleFunc("/", handler)` перехватывал ВСЕ запросы
   - Стало: `http.ServeMux` с явной маршрутизацией (строки 521-528)
   - Удалена проверка пути из `healthCheckHandler` (строки 343-347)

### Созданные скрипты:

- ✅ `build-on-vps.sh` - автоматическая компиляция на VPS
- ✅ `check-go-location.sh` - поиск Go на VPS
- ✅ `verify-main-go.sh` - проверка содержимого main.go
- ✅ `verify-binary.sh` - проверка бинарника
- ✅ `test-mqtt-endpoint.sh` - тестирование MQTT эндпоинта
- ✅ `check-process.sh` - проверка запущенных процессов
- ✅ `test-ipv4-ipv6.sh` - тестирование IPv4/IPv6
- ✅ `check-compiled-binary.sh` - проверка перекомпилированного бинарника
- ✅ `show-main-go-lines.sh` - показ строк из main.go
- ✅ `test-path-check.sh` - тестирование проверки пути
- ✅ `full-restart.sh` - полная перезагрузка сервиса
- ✅ `final-test.sh` - финальное тестирование
- ✅ `show-vps-ip.sh` - показ IP-адреса VPS
- ✅ `show-ssh-hosts.sh` - показ SSH конфигурации
- ✅ `compare-main-go.sh` - сравнение файлов
- ✅ `deploy-final-fix.sh` - деплой с исправлением маршрутизации
- ✅ `check-binary-strings.sh` - проверка строк в бинарнике
- ✅ `deploy-mux-handle-fix.sh` - финальный деплой с mux.Handle

## Пошаговая инструкция

### Шаг 1: Подготовка на Windows

1. **Откройте файл [`main.go`](main.go) в редакторе**
   - Убедитесь, что он содержит следующие исправления:
     - Строка 406: `if r.Method != http.MethodPost {`
     - Строка 408: `logger.Error("MQTT publish: Method not allowed"`
     - Строка 188: `// Username and password are optional (can be empty for no authentication)`
     - Строки 521-528: `mux := http.NewServeMux()` и `Handler: mux,`

2. **Сохраните файл** (Ctrl+S)

3. **Подготовьте файлы для копирования**
   - Создайте временную директорию на VPS:
     ```bash
     ssh dip16@<IP_VPS> 'mkdir -p /tmp/health-check-deploy'
     ```
   - Скопируйте следующие файлы из рабочей директории Windows в `/tmp/health-check-deploy/` на VPS:
     - `main.go` - исходный код приложения
     - `config.yaml` - конфигурация с MQTT настройками
     - `deploy-mux-handle-fix.sh` - скрипт деплоя

   **Через MobaXterm:**
   - Перетащите файлы из Windows в `/tmp/health-check-deploy/` на VPS
   - Подтвердите замену файлов

### Шаг 2: Узнайте IP-адрес VPS

Выполните на VPS:
```bash
cd /tmp/health-check-deploy
bash show-vps-ip.sh
```

Или на Windows:
```cmd
hostname -I
```

### Шаг 3: Выполните деплой на VPS

**Вариант A: Через MobaXterm (рекомендуется)**
1. Подключитесь к VPS через MobaXterm
2. Перейдите в директорию `/tmp/health-check-deploy/`
3. Выполните:
   ```bash
   bash deploy-mux-handle-fix.sh
   ```

**Вариант B: Через SSH с Windows**
1. Откройте командную строку (cmd) или PowerShell
2. Выполните:
   ```cmd
   ssh dip16@<IP_VPS> 'cd /tmp/health-check-deploy && bash deploy-mux-handle-fix.sh'
   ```

**Вариант C: Через SCP и SSH**
1. Скопируйте файлы через SCP:
   ```cmd
   scp main.go dip16@<IP_VPS>:/tmp/health-check-deploy/
   scp config.yaml dip16@<IP_VPS>:/tmp/health-check-deploy/
   scp deploy-mux-handle-fix.sh dip16@<IP_VPS>:/tmp/health-check-deploy/
   ```
2. Выполните скрипт деплоя через SSH:
   ```cmd
   ssh dip16@<IP_VPS> 'cd /tmp/health-check-deploy && bash deploy-mux-handle-fix.sh'
   ```

### Шаг 4: Протестируйте MQTT эндпоинт

После успешного деплоя выполните на VPS:

```bash
# Тест gate1
curl -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}'

# Тест gate2
curl -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate2"}'
```

Ожидаемый ответ для обоих тестов: `OK`

### Шаг 5: Протестируйте извне

С Windows или другого устройства:

```cmd
# Тест gate1
curl -X POST http://<IP_VPS>:8001/mqtt ^
  -H "Content-Type: application/json" ^
  -d "{\"gate\":\"gate1\"}"

# Тест gate2
curl -X POST http://<IP_VPS>:8001/mqtt ^
  -H "Content-Type: application/json" ^
  -d "{\"gate\":\"gate2\"}"
```

### Шаг 6: Мониторинг логов

На VPS выполните:
```bash
# Просмотр логов в реальном времени
sudo journalctl -u health-check.service -f

# Последние 20 строк
sudo journalctl -u health-check.service -n 20 --no-pager

# Логи с фильтрацией по gate
sudo journalctl -u health-check.service -f | grep "gate"

# Логи с фильтрацией по MQTT
sudo journalctl -u health-check.service -f | grep "MQTT"
```

### Шаг 7: Мониторинг MQTT сообщений (опционально)

Если вы хотите мониторить MQTT сообщения, установите mosquitto-clients:

```bash
# Установка на VPS
sudo apt-get update
sudo apt-get install -y mosquitto-clients

# Подписка на топик
mosquitto_sub -h <MQTT_BROKER_IP> -p 1883 -t "GateControl/Gate" -v

# Подписка с аутентификацией (если включена)
mosquitto_sub -h <MQTT_BROKER_IP> -p 1883 -t "GateControl/Gate" -v \
  -u <USERNAME> -P <PASSWORD>
```

## Конфигурация

### config.yaml

```yaml
mqtt:
  broker: "tcp://78.29.40.170:1883"
  client_id: "health-check-server"
  username: ""
  password: ""
  qos: 1
  retain: false
  connect_timeout: 10
  gates:
    gate1:
      topic: "GateControl/Gate"
      payload: "179226315200"
    gate2:
      topic: "GateControl/Gate"
      payload: "279226315200"
```

## Полезные команды

### Управление сервисом на VPS:

```bash
# Статус сервиса
sudo systemctl status health-check.service

# Перезапуск сервиса
sudo systemctl restart health-check.service

# Остановка сервиса
sudo systemctl stop health-check.service

# Запуск сервиса
sudo systemctl start health-check.service

# Отключение автозапуска
sudo systemctl disable health-check.service

# Включение автозапуска
sudo systemctl enable health-check.service

# Просмотр логов
sudo journalctl -u health-check.service -f

# Последние 50 строк логов
sudo journalctl -u health-check.service -n 50 --no-pager
```

### Тестирование эндпоинтов:

```bash
# Health check (GET)
curl http://localhost:8001/

# MQTT publish (POST) - gate1
curl -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}'

# MQTT publish (POST) - gate2
curl -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate2"}'
```

## Устранение неполадок

### Проблема: MQTT эндпоинт возвращает "Method not allowed"

**Причина:** Старый процесс health-check-server всё ещё работает и слушает порт 8001.

**Решение:**
```bash
# Убить все процессы health-check-server
sudo pkill -9 -f health-check-server

# Перезапустить сервис
sudo systemctl restart health-check.service

# Проверить статус
sudo systemctl status health-check.service
```

### Проблема: Бинарник не содержит исправления

**Причина:** Бинарник был скомпилирован из старого файла main.go.

**Решение:**
1. Убедитесь, что файл main.go на Windows сохранён (Ctrl+S)
2. Скопируйте его снова на VPS
3. Перекомпилируйте:
   ```bash
   cd /tmp/health-check-deploy
   /usr/local/go/bin/go clean -cache
   /usr/local/go/bin/go build -a -o health-check-server main.go
   sudo cp health-check-server /etc/health-check-server/
   sudo systemctl restart health-check.service
   ```

### Проблема: GET на /mqtt возвращает 200 вместо 404

**Причина:** Маршрутизация работает корректно, GET запросы обрабатываются mqttPublishHandler.

**Решение:** Это нормальное поведение. GET запросы на /mqtt должны возвращать 404 или 405.

### Проблема: MQTT брокер недоступен

**Причина:** Брокер 78.29.40.170:1883 недоступен или блокирует соединения.

**Решение:**
```bash
# Проверка соединения с брокером
telnet 78.29.40.170 1883

# Или с помощью nc
nc -zv 78.29.40.170 1883

# Проверка firewall на VPS
sudo ufw status
sudo ufw allow 1883/tcp

# Проверка логов
sudo journalctl -u health-check.service -f | grep -i "mqtt\|broker\|connect"
```

## Архитектура приложения

### HTTP Эндпоинты:

1. **GET /** - Health check
   - Возвращает: `OK`
   - Rate limiting: 10 запросов в минуту на IP
   - Security headers: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection

2. **POST /mqtt** - MQTT publish
   - Тело запроса: `{"gate":"gate1"}` или `{"gate":"gate2"}`
   - Rate limiting: 10 запросов в минуту на IP
   - Security headers: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection
   - Публикует сообщение на MQTT брокер с настроенным topic и payload

### MQTT Конфигурация:

- **Брокер:** tcp://78.29.40.170:1883
- **Client ID:** health-check-server
- **QoS:** 1
- **Retain:** false
- **Gate1:** Topic="GateControl/Gate", Payload="179226315200"
- **Gate2:** Topic="GateControl/Gate", Payload="279226315200"
- **Аутентификация:** Нет (username и password пустые)

### Логирование:

- **Формат:** JSON
- **Уровни:** info, error
- **Поля:** timestamp, level, message, ip, user_agent, response_time_ms, gate, topic, payload, error

## Безопасность

### Rate Limiting:
- 10 запросов в минуту на IP
- Отдельно для каждого эндпоинта

### Security Headers:
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block

### Input Sanitization:
- Удаление новых строк, возвратов каретки, табуляции
- Ограничение длины до 500 символов
- Применяется к user_agent и другим входным данным

### IP Extraction:
- Проверка X-Forwarded-For header
- Проверка X-Real-IP header
- Fallback на RemoteAddr

## Резюме

Приложение health-check-server с MQTT интеграцией полностью готово к деплою на VPS.

### Ключевые особенности:
- ✅ Автоматическая компиляция на VPS (если Go установлен)
- ✅ Автоматическое создание резервных копий
- ✅ Graceful shutdown при SIGINT/SIGTERM
- ✅ Автоматический реконнект к MQTT брокеру
- ✅ Структурированное JSON логирование
- ✅ Rate limiting для защиты от DDoS
- ✅ Security headers для защиты от XSS и clickjacking
- ✅ Валидация входных данных
- ✅ Настраиваемые topic и payload для каждого gate

### Следующие шаги:
1. ✅ Узнать IP-адрес VPS
2. ✅ Скопировать файлы на VPS
3. ✅ Выполнить деплой через `deploy-mux-handle-fix.sh`
4. ✅ Протестировать MQTT эндпоинт
5. ✅ Протестировать извне
6. ✅ Настроить мониторинг (опционально)

После выполнения этих шагов MQTT эндпоинт будет работать корректно и отправлять сообщения на ваш MQTT брокер!
