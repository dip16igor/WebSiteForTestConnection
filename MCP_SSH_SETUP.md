# Настройка SSH для MCP

## Проблема

SSH аутентификация через MCP не удалась с ошибкой:
```
SSH connection failed: All configured authentication methods failed
```

## Решение

Вам нужно настроить SSH ключ для MCP. Вот несколько вариантов:

### Вариант 1: Использовать SSH ключ (рекомендуется)

1. **Создать SSH ключ на вашем компьютере** (если еще нет):
```bash
ssh-keygen -t rsa -b 4096 -C "mcp-ssh"
```

2. **Добавить публичный ключ на VPS**:
```bash
# Скопировать публичный ключ
cat ~/.ssh/id_rsa.pub

# Добавить на VPS
ssh-copy-id -i ~/.ssh/id_rsa.pub root@109.69.19.36
```

Или вручную:
```bash
# На VPS
mkdir -p ~/.ssh
echo "ВАШ_ПУБЛИЧНЫЙ_КЛЮЧ" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

3. **Настроить переменную окружения для SSH ключа**:
```bash
# Добавить в ~/.bashrc или ~/.zshrc
export SSH_PRIVATE_KEY_PATH=~/.ssh/id_rsa

# Перезагрузить
source ~/.bashrc
```

### Вариант 2: Использовать парольную аутентификацию

Если вы предпочитаете использовать пароль вместо ключа, убедитесь, что:

1. **SSH доступ по паролю включен** на VPS:
```bash
# На VPS проверьте /etc/ssh/sshd_config
# Убедитесь, что:
# PasswordAuthentication yes
```

2. **MCP настроен на использование пароля**:
```bash
# Установите переменную окружения
export SSH_PASSWORD="ваш_пароль_root"
```

### Вариант 3: Ручное развертывание

Если MCP SSH не работает, используйте ручное развертывание:

1. **Передать файлы на VPS**:
```bash
scp update-second-mqtt-broker.sh root@109.69.19.36:/root/
scp config.yaml root@109.69.19.36:/etc/health-check-server/
```

2. **Подключиться к VPS**:
```bash
ssh root@109.69.19.36
```

3. **Запустить обновление**:
```bash
chmod +x /root/update-second-mqtt-broker.sh
cd /root
./update-second-mqtt-broker.sh
```

## Проверка SSH подключения

Перед использованием MCP SSH, проверьте, что SSH работает:

```bash
# Тест подключения
ssh -o ConnectTimeout=5 root@109.69.19.36 "echo 'SSH connection successful'"

# Если работает, попробуйте MCP снова
```

## Альтернатива: Использовать существующий скрипт развертывания

Если у вас уже есть рабочий скрипт развертывания (например, `deploy-vps.sh`), вы можете обновить его:

1. **Открыть существующий скрипт**:
```bash
nano deploy-vps.sh
```

2. **Добавить обновление config.yaml** после копирования binary:
```bash
# После Step 5 добавить:
if [ -f config.yaml ]; then
    cp config.yaml "$CONFIG_FILE"
    print_success "Config file updated"
fi
```

3. **Запустить обновленный скрипт**:
```bash
./deploy-vps.sh
```

## Рекомендация

Для надежности и безопасности, **рекомендуется** использовать SSH ключ аутентификацию вместо пароля. Это обеспечит:
- ✅ Более безопасное подключение
- ✅ Работу с MCP без проблем
- ✅ Автоматизацию развертываний

После настройки SSH ключа, MCP должен работать без проблем.
