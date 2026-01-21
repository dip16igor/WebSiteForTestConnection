# Инструкция по обновлению Health Check Server с поддержкой второго MQTT брокера

## Обзор

Этот скрипт обновит health-check-server на VPS с новой функциональностью:
- Поддержка второго MQTT брокера (опционально)
- Новый HTTP endpoint `/action` для управления WebRadio2
- Команды `vol+` и `vol-` для управления громкостью

## Предварительные требования

- VPS с Ubuntu 20.04+
- Root доступ или sudo права
- Существующий health-check.service должен быть запущен
- Go должен быть установлен (скрипт проверит это)

## Шаги по обновлению

### 1. Скопировать скрипт на VPS

Скопируйте файл `update-second-mqtt-broker.sh` на VPS:

```bash
# С вашего локального компьютера
scp update-second-mqtt-broker.sh root@109.69.19.36:/root/

# Или используйте ваш любимый метод передачи файлов
```

### 2. Подключиться к VPS

```bash
ssh root@109.69.19.36
```

### 3. Сделать скрипт исполняемым

```bash
chmod +x update-second-mqtt-broker.sh
```

### 4. Запустить скрипт обновления

```bash
sudo ./update-second-mqtt-broker.sh
```

## Что делает скрипт

Скрипт выполнит следующие шаги:

1. **Резервное копирование**: Создаст резервную копию текущего binary
2. **Создание рабочей директории**: `/tmp/health-check-update`
3. **Создание main.go**: Создаст новый файл с поддержкой второго MQTT брокера
4. **Проверка Go**: Проверит, что Go установлен
5. **Компиляция**: Скомпилирует новый binary
6. **Копирование**: Скопирует новый binary в `/usr/local/bin/`
7. **Обновление конфигурации**: Добавит секцию `mqtt2` в config.yaml
8. **Перезапуск сервиса**: Перезапустит health-check.service
9. **Проверка статуса**: Проверит, что сервис запущен
10. **Тестирование endpoints**: Проверит все HTTP endpoints
11. **Отображение логов**: Покажет последние логи
12. **Очистка**: Удалит временные файлы

## После обновления

### Проверить сервис

```bash
# Проверить статус
systemctl status health-check.service

# Посмотреть логи в реальном времени
journalctl -u health-check.service -f
```

### Тестирование новых endpoints

```bash
# Тест health check (существующий)
curl http://localhost:8001

# Тест MQTT publish (существующий)
curl "http://localhost:8001/mqtt?gate=gate1"

# Тест action endpoint (НОВЫЙ)
curl "http://localhost:8001/action?action=vol+"

# Тест action endpoint с vol- (НОВЫЙ)
curl "http://localhost:8001/action?action=vol-"
```

### Настройка второго MQTT брокера

После обновления конфигурация уже содержит правильные данные. При необходимости отредактируйте:

```bash
nano /etc/health-check-server/config.yaml
```

Секция `mqtt2` уже настроена с вашими данными:

```yaml
mqtt2:
  # MQTT broker address (tcp://hostname:port)
  broker: "tcp://46.8.233.146:1883"
  
  # MQTT client ID (must be unique)
  client_id: "IgorSmartWatch-WebRadio2"
  
  # Authentication credentials
  username: "dip16"
  password: "nirvana7"
  
  # Quality of Service level (0, 1, or 2)
  qos: 1
  
  # Whether to retain messages on the broker
  retain: false
  
  # Connection timeout in seconds
  connect_timeout: 10
```

После редактирования перезапустите сервис:

```bash
systemctl restart health-check.service
```

## Откат изменений

Если что-то пойдет не так, можно откатиться:

```bash
# Найти резервную копию
ls -la /usr/local/bin/health-check-server.backup.*

# Восстановить из резервной копии
sudo systemctl stop health-check.service
sudo cp /usr/local/bin/health-check-server.backup.YYYYMMDD_HHMMSS /usr/local/bin/health-check-server
sudo systemctl start health-check.service
```

## Устранение неполадок

### Скрипт не запускается

```bash
# Проверить права доступа
ls -la update-second-mqtt-broker.sh

# Установить права
chmod +x update-second-mqtt-broker.sh

# Запустить с sudo
sudo ./update-second-mqtt-broker.sh
```

### Ошибка компиляции

```bash
# Проверить версию Go
go version

# Установить Go если нужно
apt update && apt install -y golang-go
```

### Сервис не запускается

```bash
# Проверить логи
journalctl -u health-check.service -n 50

# Проверить конфигурацию
cat /etc/health-check-server/config.yaml

# Проверить binary
ls -la /usr/local/bin/health-check-server
```

### Port 8001 не доступен

```bash
# Проверить firewall
sudo ufw status

# Разрешить порт если нужно
sudo ufw allow 8001/tcp

# Проверить, что порт слушается
sudo netstat -tlnp | grep 8001
```

## Внешнее тестирование

После успешного обновления, протестируйте с вашего локального компьютера:

```bash
# Замените 109.69.19.36 на ваш IP если нужно
curl http://109.69.19.36:8001
curl "http://109.69.19.36:8001/mqtt?gate=gate1"
curl "http://109.69.19.36:8001/action?action=vol+"
```

## Новая функциональность

### Endpoint `/action`

Новый endpoint для управления WebRadio2 через второй MQTT брокер:

- `GET /action?action=vol+` - Увеличить громкость
- `GET /action?action=vol-` - Уменьшить громкость

Публикует в топик `Home/WebRadio2/Action` на втором MQTT брокере.

### Опциональный второй брокер

Второй MQTT брокер полностью опционален:
- Если секция `mqtt2` отсутствует в config.yaml, endpoint `/action` вернет ошибку
- Система работает нормально без второго брокера
- Первый MQTT брокер продолжает работать как обычно

### Независимая работа

Оба MQTT брокера работают независимо:
- Ошибка одного брокера не влияет на другой
- Отдельное rate limiting для каждого endpoint
- Отдельное логирование для каждого брокера

## Мониторинг

Добавьте новые endpoints в вашу мониторинговую систему:

```bash
# Health check
http://109.69.19.36:8001

# Action endpoint (vol+)
http://109.69.19.36:8001/action?action=vol+

# Action endpoint (vol-)
http://109.69.19.36:8001/action?action=vol-
```

## Поддержка

Если возникнут проблемы:

1. Проверьте логи: `journalctl -u health-check.service -f`
2. Проверьте конфигурацию: `cat /etc/health-check-server/config.yaml`
3. Проверьте статус сервиса: `systemctl status health-check.service`
4. Используйте откат если нужно (см. раздел "Откат изменений")
