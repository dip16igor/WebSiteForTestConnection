# MCP SSH-VPS Справочник

> Создано: 2026-01-21  
> Цель: Документация по использованию MCP ssh-vps инструментов для быстрой отсылки

---

## Конфигурация MCP

Файл: [`.kilocode/mcp.json`](.kilocode/mcp.json)

```json
{
  "mcpServers": {
    "ssh-vps": {
      "command": "npx",
      "args": ["-y", "@idletoaster/ssh-mcp-server"],
      "env": {
        "SSH_CONFIG_PATH": "C:/Users/dip16/.ssh/config"
      },
      "alwaysAllow": [
        "remote-ssh",
        "ssh-edit-block",
        "ssh-read-lines",
        "ssh-search-code",
        "ssh-write-chunk"
      ]
    }
  }
}
```

---

## Параметры подключения VPS

| Параметр | Значение |
|----------|----------|
| **Host** | `109.69.19.36` (IP адрес, НЕ имя хоста!) |
| **Port** | `22` |
| **User** | `dip16` |
| **PrivateKeyPath** | `C:\Users\dip16\.ssh\id_rsa` (опционально) |

### ⚠️ ВАЖНОЕ ЗАМЕЧАНИЕ

**НЕ используйте имена хостов из SSH конфигурации** (`myvps`, `efdcjasiej`).  
MCP ssh-vps сервер **НЕ читает** `~/.ssh/config` для разрешения имён хостов.  
**Всегда используйте IP адрес напрямую: `109.69.19.36`**

---

## Доступные инструменты

### 1. remote-ssh
Выполнение команд на удалённом сервере.

```javascript
mcp--ssh-vps--remote-ssh({
  host: "109.69.19.36",
  port: 22,
  user: "dip16",
  command: "echo 'Hello World'"
})
```

**Примеры команд:**
- `pwd` - текущая директория
- `ls -la /home/dip16` - список файлов
- `systemctl status health-check-server` - статус сервиса
- `rm /path/to/file` - удаление файла

---

### 2. ssh-read-lines
Чтение строк из удалённых файлов (эффективно для больших файлов).

```javascript
mcp--ssh-vps--ssh-read-lines({
  host: "109.69.19.36",
  port: 22,
  user: "dip16",
  filePath: "/home/dip16/main.go",
  startLine: 1,
  endLine: 100,
  maxLines: 100  // опционально, по умолчанию 100
})
```

---

### 3. ssh-search-code
Поиск паттернов в файлах на удалённом сервере.

```javascript
mcp--ssh-vps--ssh-search-code({
  host: "109.69.19.36",
  port: 22,
  user: "dip16",
  path: "/home/dip16",
  pattern: "health-check",
  filePattern: "*.go",
  ignoreCase: false,  // опционально
  maxResults: 50,    // опционально
  contextLines: 2    // опционально
})
```

---

### 4. ssh-write-chunk
Запись содержимого в удалённые файлы.

```javascript
mcp--ssh-vps--ssh-write-chunk({
  host: "109.69.19.36",
  port: 22,
  user: "dip16",
  filePath: "/home/dip16/test.txt",
  content: "# Test file\nContent here",
  mode: "rewrite"  // или "append"
})
```

---

### 5. ssh-edit-block
Редактирование блоков текста в удалённых файлах.

```javascript
mcp--ssh-vps--ssh-edit-block({
  host: "109.69.19.36",
  port: 22,
  user: "dip16",
  filePath: "/home/dip16/test.txt",
  oldText: "old text to replace",
  newText: "new text",
  expectedReplacements: 1  // опционально
})
```

---

## Результаты тестов (2026-01-21)

| Инструмент | Статус | Тест |
|------------|--------|------|
| `remote-ssh` | ✅ Успешно | `echo "MCP SSH-VPS connection test successful"` |
| `ssh-read-lines` | ✅ Успешно | Прочитан `/etc/hostname` → `efdcjasiej` |
| `ssh-search-code` | ✅ Успешно | Поиск "health-check" в `*.go` → 3 совпадения |
| `ssh-write-chunk` | ✅ Успешно | Создан файл `/home/dip16/mcp-test-file.txt` (99 байт) |
| `ssh-edit-block` | ✅ Успешно | Заменён 1 блок в тестовом файле |

---

## Частые команды для работы с VPS

### Проверка статуса сервисов
```bash
systemctl status health-check-server
systemctl status health-check
journalctl -u health-check-server -n 50
```

### Работа с бинарными файлами
```bash
ls -la /home/dip16/
file /home/dip16/health-check-server
strings /home/dip16/health-check-server | head -20
```

### Перезапуск сервисов
```bash
systemctl restart health-check-server
systemctl daemon-reload
```

### Проверка сети
```bash
curl -v http://localhost:8080/health
netstat -tlnp | grep 8080
```

---

## Структура проекта на VPS

```
/home/dip16/
├── main.go                    # Основной файл проекта
├── health-check-server/        # Директория health-check сервера
│   └── main.go
├── tmp/                        # Временные файлы
│   └── main.go
└── config.yaml                 # Конфигурация
```

---

## Диагностика проблем

### Ошибка: "getaddrinfo ENOTFOUND"
**Причина:** Использовано имя хоста вместо IP адреса.  
**Решение:** Используйте `109.69.19.36` вместо `myvps` или `efdcjasiej`.

### Ошибка: "SSH connection failed"
**Проверьте:**
1. IP адрес правильный: `109.69.19.36`
2. Порт: `22`
3. Пользователь: `dip16`
4. SSH ключ существует: `C:\Users\dip16\.ssh\id_rsa`
5. Сервер доступен: `ping 109.69.19.36`

---

## Быстрый старт

Для выполнения команды на VPS:

```javascript
mcp--ssh-vps--remote-ssh({
  host: "109.69.19.36",
  port: 22,
  user: "dip16",
  command: "ваша команда здесь"
})
```

Для чтения файла:

```javascript
mcp--ssh-vps--ssh-read-lines({
  host: "109.69.19.36",
  port: 22,
  user: "dip16",
  filePath: "/путь/к/файлу",
  startLine: 1,
  endLine: 100
})
```
