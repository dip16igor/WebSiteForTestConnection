# Руководство по использованию Health Check Server

## Обзор

Health Check Server - это простой HTTP сервер, который отвечает HTTP 200 на порту 8001. Идеально подходит для мониторинга работоспособности VPS.

## Как работает сервис

- **Порт**: 8001
- **Метод**: Только GET запросы
- **Ответ**: HTTP 200 с телом "OK"
- **Заголовки безопасности**: X-Content-Type-Options, X-Frame-Options, X-XSS-Protection
- **Ограничение скорости**: 10 запросов в минуту на IP

## Локальное тестирование

### Базовая проверка
```bash
# Проверить работает ли сервер
curl http://localhost:8001

# Ответ: OK
```

### Проверка заголовков
```bash
# Посмотреть все заголовки
curl -I http://localhost:8001

# Проверить конкретный заголовок
curl -I http://localhost:8001 | grep -i "X-Frame-Options"
```

### Проверка ограничения скорости
```bash
# Отправить 12 запросов быстро
for i in {1..12}; do curl -s -w "%{http_code}\n" http://localhost:8001; done
# 11-й запрос должен вернуть 429
```

## Удаленное использование

### 1. Базовый HTTP запрос
```bash
# С любого компьютера в интернете
curl http://YOUR_VPS_IP:8001

# Пример:
curl http://192.168.1.100:8001
curl http://203.0.113.42:8001
```

### 2. Мониторинг через браузер
```
# Просто откройте в браузере
http://YOUR_VPS_IP:8001
```

### 3. Использование в мониторинговых системах

#### Nagios/Icinga
```bash
# В commands.cfg:
define command{
    command_name    check_http_health
    command_line    $USER1$/check_http -H $HOSTADDRESS$ -p 8001 -s "OK"
}

# В services.cfg:
define service{
    use                     generic-service
    host_name               your-vps
    service_description       Health Check
    check_command           check_http_health
}
```

#### Zabbix
```bash
# Создать элемент данных:
# Тип: HTTP агент
# URL: http://YOUR_VPS_IP:8001
# Код ответа: 200
# Тело ответа: OK
```

#### Prometheus + Blackbox Exporter
```yaml
# В blackbox.yml:
modules:
  http_2xx:
    prober: http
    timeout: 5s
    http:
      valid_http_versions:
        - "HTTP/1.1"
        - "HTTP/2"
      valid_status_codes: [200]
      method: GET
      fail_if_matches_regexp:
        - ".*Error.*"
      fail_if_not_matches_regexp:
        - "OK"
```

#### UptimeRobot / Pingdom
```
# Настройка мониторинга:
# URL: http://YOUR_VPS_IP:8001
# Проверка: HTTP
# Ожидаемый код: 200
# Интервал: 1 минута
```

### 4. Программный мониторинг

#### Python
```python
import requests

def check_health(vps_ip):
    try:
        response = requests.get(f"http://{vps_ip}:8001", timeout=5)
        return response.status_code == 200 and response.text == "OK"
    except:
        return False

# Использование
if check_health("192.168.1.100"):
    print("✅ VPS is healthy")
else:
    print("❌ VPS is down")
```

#### Node.js
```javascript
const http = require('http');

function checkHealth(vpsIp) {
    return new Promise((resolve, reject) => {
        const req = http.get(`http://${vpsIp}:8001`, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                resolve(res.statusCode === 200 && data === 'OK');
            });
        });
        
        req.on('error', reject);
        req.setTimeout(5000, () => req.abort());
    });
}

// Использование
checkHealth('192.168.1.100')
    .then(healthy => console.log(healthy ? '✅ VPS is healthy' : '❌ VPS is down'))
    .catch(err => console.error('Error:', err));
```

#### Go
```go
package main

import (
    "fmt"
    "io"
    "net/http"
    "time"
)

func checkHealth(vpsIP string) bool {
    client := &http.Client{
        Timeout: 5 * time.Second,
    }
    
    resp, err := client.Get(fmt.Sprintf("http://%s:8001", vpsIP))
    if err != nil {
        return false
    }
    defer resp.Body.Close()
    
    body, err := io.ReadAll(resp.Body)
    if err != nil {
        return false
    }
    
    return resp.StatusCode == 200 && string(body) == "OK"
}

func main() {
    if checkHealth("192.168.1.100") {
        fmt.Println("✅ VPS is healthy")
    } else {
        fmt.Println("❌ VPS is down")
    }
}
```

## Настройка firewall для удаленного доступа

### Открыть порт для всех
```bash
# Разрешить доступ с любого IP
sudo ufw allow 8001/tcp

# Проверить правила
sudo ufw status
```

### Ограничить доступ для конкретных IP
```bash
# Разрешить только для определенных IP
sudo ufw allow from 192.168.1.0/24 to any port 8001 proto tcp
sudo ufw allow from 203.0.113.0/24 to any port 8001 proto tcp

# Заблокировать остальные
sudo ufw deny 8001/tcp
```

## Мониторинг логов

### Просмотр логов в реальном времени
```bash
# Все логи
sudo journalctl -u health-check-server -f

# Только ошибки
sudo journalctl -u health-check-server -p err -f

# Только успешные запросы
sudo journalctl -u health-check-server | grep "Health check request processed"
```

### Анализ логов
```bash
# Топ IP адресов
sudo journalctl -u health-check-server | jq -r '.ip' | sort | uniq -c | sort -nr

# Запросы с ошибками
sudo journalctl -u health-check-server | grep "Rate limit exceeded"

# Медленные запросы (>100ms)
sudo journalctl -u health-check-server | jq 'select(.response_time_ms | tonumber > 100)'

# Экспорт в CSV для анализа
sudo journalctl -u health-check-server --output json | jq -r '[.timestamp, .ip, .user_agent, .response_time_ms] | @csv' > health_logs.csv
```

## Интеграция с CI/CD

### GitHub Actions
```yaml
# .github/workflows/health-check.yml
name: Health Check

on:
  schedule:
    - cron: '*/5 * * * *'  # каждые 5 минут

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
    - name: Check VPS Health
      run: |
        response=$(curl -s -w "%{http_code}" http://YOUR_VPS_IP:8001)
        if [ "$response" != "200" ]; then
          echo "❌ Health check failed"
          exit 1
        fi
        echo "✅ Health check passed"
```

### Jenkins Pipeline
```groovy
pipeline {
    agent any
    triggers {
        cron('H/5 * * * *')  // каждые 5 минут
    }
    
    stages {
        stage('Health Check') {
            steps {
                sh '''
                    response=$(curl -s -w "%{http_code}" http://YOUR_VPS_IP:8001)
                    if [ "$response" != "200" ]; then
                        echo "❌ Health check failed"
                        exit 1
                    fi
                    echo "✅ Health check passed"
                '''
            }
        }
    }
}
```

## Алерты и уведомления

### Email алерты
```bash
# Скрипт для проверки и отправки email
#!/bin/bash
if ! curl -f http://YOUR_VPS_IP:8001 > /dev/null 2>&1; then
    echo "VPS is down!" | mail -s "VPS Alert" admin@example.com
fi
```

### Telegram алерты
```bash
# С использованием Telegram Bot API
#!/bin/bash
BOT_TOKEN="your_bot_token"
CHAT_ID="your_chat_id"

if ! curl -f http://YOUR_VPS_IP:8001 > /dev/null 2>&1; then
    curl -s "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
         -d "chat_id=$CHAT_ID" \
         -d "text=🚨 VPS Health Check Failed!"
fi
```

## Продвинутые сценарии использования

### Load Balancing Health Checks
```bash
# Проверка нескольких серверов
servers=("192.168.1.100" "192.168.1.101" "192.168.1.102")

for server in "${servers[@]}"; do
    if curl -f "http://$server:8001" > /dev/null 2>&1; then
        echo "✅ $server is healthy"
    else
        echo "❌ $server is down"
    fi
done
```

### Географический мониторинг
```bash
# Проверка с разных локаций
locations=("us-east" "eu-west" "asia-southeast")

for location in "${locations[@]}"; do
    echo "Checking from $location..."
    # Здесь можно использовать VPN или прокси для проверки с разных локаций
    if curl -f "http://YOUR_VPS_IP:8001" > /dev/null 2>&1; then
        echo "✅ Accessible from $location"
    else
        echo "❌ Not accessible from $location"
    fi
done
```

## Заключение

Health Check Server предоставляет простой и надежный способ мониторинга работоспособности VPS. Вы можете интегрировать его с любыми мониторинговыми системами, использовать в CI/CD пайплайнах или создавать собственные решения для мониторинга.

Ключевые преимущества:
- ✅ Простота использования
- ✅ Минимальные требования к ресурсам
- ✅ Безопасность (ограничение скорости, заголовки)
- ✅ Детальное логирование
- ✅ Гибкость интеграции