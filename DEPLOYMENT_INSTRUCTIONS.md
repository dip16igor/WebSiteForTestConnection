# Инструкция по обновлению Health Check Server на VPS

## Обзор

Приложение обновлено с поддержкой MQTT интеграции. Теперь вы можете:
- Публиковать сообщения в MQTT брокер через HTTP запросы
- Настраивать topic и payload для каждого gate (gate1, gate2)
- Использовать существующий health check endpoint без изменений

## Подготовка файлов

### На Windows (где у вас исходники):

Вам нужно подготовить 3 файла для загрузки на VPS:

1. **health-check-server** - скомпилированный бинарник
   ```bash
   GOOS=linux GOARCH=amd64 go build -o health-check-server main.go
   ```

2. **config.yaml** - конфигурационный файл с вашими настройками MQTT
   ```bash
   # Файл уже создан с вашими данными:
   # Broker: 78.29.40.170:1883
   # Topic: GateControl/Gate
   # Payload gate1: 179226315200
   # Payload gate2: 279226315200
   ```

3. **deploy-vps.sh** - скрипт автоматического развёртывания
   ```bash
   # Скрипт уже создан и готов к использованию
   ```

### Проверьте файлы перед отправкой:

```bash
# Убедитесь, что файлы существуют:
ls -lh health-check-server config.yaml deploy-vps.sh

# Скрипт должен быть исполняемым:
# На Windows: файл должен быть зелёным (исполняемым)
```

## Способ 1: Использование deploy-vps.sh (Рекомендуемый)

### Шаг 1: Подключитесь к VPS через MobaXterm

Откройте MobaXterm и подключитесь к вашему VPS Ubuntu.

### Шаг 2: Создайте временную директорию на VPS

```bash
mkdir -p /tmp/deploy
```

### Шаг 3: Загрузите файлы на VPS

**Через MobaXterm:**

1. Нажмите кнопку "SCP/SFTP" в MobaXterm
2. Перетащите следующие файлы в `/tmp/deploy/`:
   - `health-check-server`
   - `config.yaml`
   - `deploy-vps.sh`

**Или через SFTP клиент (FileZilla, WinSCP):**

1. Подключитесь к VPS по SFTP
2. Перетащите файлы в `/tmp/deploy/`

### Шаг 4: Сделайте скрипт исполняемым

```bash
chmod +x /tmp/deploy/deploy-vps.sh
```

### Шаг 5: Запустите скрипт развёртывания

```bash
sudo /tmp/deploy/deploy-vps.sh
```

Скрипт автоматически выполнит следующие шаги:
1. ✅ Создаст резервную копию текущего бинарника
2. ✅ Создаст директорию `/etc/health-check-server`
3. ✅ Скопирует `config.yaml` в `/etc/health-check-server/config.yaml`
4. ✅ Установит правильные права (600) на конфигурационный файл
5. ✅ Заменит бинарник в `/usr/local/bin/health-check-server`
6. ✅ Перезапустит systemd сервис
7. ✅ Протестирует health check endpoint
8. ✅ Протестирует MQTT publish endpoint для gate1 и gate2
9. ✅ Покажет последние логи
10. ✅ Покажет статус сервиса

### Шаг 6: Проверьте результат

После выполнения скрипта проверьте:

```bash
# Проверьте статус сервиса
systemctl status health-check-server

# Протестируйте health endpoint
curl http://localhost:8001

# Протестируйте MQTT publish для gate1
curl -X GET http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate": "gate1"}'

# Протестируйте MQTT publish для gate2
curl -X GET http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate": "gate2"}'

# Посмотрите логи
sudo journalctl -u health-check-server -f
```

## Способ 2: Ручное развёртывание

Если автоматический скрипт не работает, вы можете выполнить шаги вручную:

### На VPS выполните:

```bash
# 1. Создайте директорию для конфигурации
sudo mkdir -p /etc/health-check-server

# 2. Скопируйте config.yaml
sudo cp /tmp/deploy/config.yaml /etc/health-check-server/config.yaml

# 3. Установите права
sudo chmod 600 /etc/health-check-server/config.yaml
sudo chown healthcheck:healthcheck /etc/health-check-server/config.yaml

# 4. Замените бинарник
sudo cp /tmp/deploy/health-check-server /usr/local/bin/health-check-server
sudo chmod +x /usr/local/bin/health-check-server

# 5. Перезапустите сервис
sudo systemctl restart health-check-server

# 6. Проверьте статус
sudo systemctl status health-check-server
```

## Проверка MQTT брокера

Убедитесь, что MQTT брокер (Mosquitto) запущен и доступен:

```bash
# Проверьте статус Mosquitto
sudo systemctl status mosquitto

# Проверьте, что порт 1883 открыт
sudo netstat -tlnp | grep :1883

# Подпишитесь на все топики для проверки
mosquitto_sub -h localhost -t "GateControl/Gate" -u username -P password
```

## Конфигурация MQTT

Если нужно изменить настройки MQTT:

```bash
# Отредактируйте конфигурационный файл
sudo nano /etc/health-check-server/config.yaml

# Перезапустите сервис после изменений
sudo systemctl restart health-check-server
```

## Тестирование

### Тест 1: Health Check Endpoint

```bash
curl http://localhost:8001
# Ожидаемый ответ: OK
```

### Тест 2: MQTT Publish для gate1

```bash
curl -X GET http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate": "gate1"}'

# Ожидаемый ответ: OK
# Проверьте в подписке Mosquitto: должно появиться "179226315200"
```

### Тест 3: MQTT Publish для gate2

```bash
curl -X GET http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate": "gate2"}'

# Ожидаемый ответ: OK
# Проверьте в подписке Mosquitto: должно появиться "279226315200"
```

## Мониторинг

### Просмотр логов в реальном времени

```bash
sudo journalctl -u health-check-server -f
```

### Фильтрация логов

```bash
# Только MQTT операции
sudo journalctl -u health-check-server | grep MQTT

# Только ошибки
sudo journalctl -u health-check-server -p err

# Только запросы с определённого IP
sudo journalctl -u health-check-server | grep "ВАШ_IP"
```

## Решение проблем

### Приложение не запускается

```bash
# Проверьте логи ошибок
sudo journalctl -u health-check-server -p err

# Проверьте конфигурационный файл
sudo cat /etc/health-check-server/config.yaml

# Попробуйте запустить вручную
sudo -u healthcheck /usr/local/bin/health-check-server
```

### MQTT не работает

```bash
# Проверьте, что Mosquitto запущен
sudo systemctl status mosquitto

# Проверьте логи Mosquitto
sudo journalctl -u mosquitto -f

# Проверьте настройки в config.yaml
sudo cat /etc/health-check-server/config.yaml

# Проверьте, что порт 1883 открыт
sudo ufw status
sudo ufw allow 1883/tcp
```

### Ошибка валидации конфигурации

```bash
# Проверьте синтаксис YAML
sudo -u healthcheck cat /etc/health-check-server/config.yaml

# Проверьте, что все обязательные поля заполнены
# - broker
# - client_id
# - gates.gate1.topic
# - gates.gate1.payload
# - gates.gate2.topic
# - gates.gate2.payload
```

## Обновление в будущем

Для обновления приложения в будущем:

1. Собрать новый бинарник на Windows
2. Загрузить `deploy-vps.sh` на VPS
3. Запустить `sudo deploy-vps.sh` на VPS

Скрипт автоматически создаст резервную копию и обновит приложение.

## Структура файлов после развёртывания

```
/etc/health-check-server/
└── config.yaml              # Конфигурация MQTT

/usr/local/bin/
└── health-check-server       # Бинарник приложения

/etc/systemd/system/
└── health-check.service        # Systemd сервис

/var/log/health-check-server/     # Логи приложения
```

## Полезные команды

```bash
# Статус сервиса
systemctl status health-check-server

# Перезапуск сервиса
sudo systemctl restart health-check-server

# Остановка сервиса
sudo systemctl stop health-check-server

# Запуск сервиса
sudo systemctl start health-check-server

# Просмотр логов
sudo journalctl -u health-check-server -f

# Просмотр последних 20 строк логов
sudo journalctl -u health-check-server -n 20

# Проверка порта
sudo netstat -tlnp | grep :8001
```
