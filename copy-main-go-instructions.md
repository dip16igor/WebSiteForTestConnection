# Инструкции по копированию main.go на VPS

## Проблема

Файл `main.go` на VPS содержит СТАРУЮ версию кода без исправлений маршрутизации.

## Что нужно сделать

### 1. На Windows (в рабочей директории проекта)

Откройте файл `main.go` в любом редакторе (VS Code, Notepad++, и т.д.) и убедитесь, что он содержит следующие строки:

**Строки 343-347 (проверка пути):**
```go
// Only handle root path
if r.URL.Path != "/" {
    http.NotFound(w, r)
    return
}
```

**Строка 406 (проверка метода):**
```go
if r.Method != http.MethodPost {
```

**Строка 408 (логирование):**
```go
logger.Error("MQTT publish: Method not allowed", map[string]string{
```

Если эти строки есть - **сохраните файл** (Ctrl+S).

### 2. Через MobaXterm

1. Откройте MobaXterm и подключитесь к VPS
2. В левой панели перейдите в директорию `/tmp/health-check-deploy/`
3. Откройте директорию проекта на Windows (где лежит main.go)
4. **Перетащите файл `main.go` из Windows в `/tmp/health-check-deploy/` на VPS**
5. Подтвердите замену файла (Yes/OK)

### 3. На VPS - проверьте, что файл обновился

```bash
cd /tmp/health-check-deploy
bash verify-main-go.sh
```

Все проверки должны показать ✓ (зелёные галочки).

### 4. На VPS - перекомпилируйте

```bash
cd /tmp/health-check-deploy
/usr/local/go/bin/go build -o health-check-server main.go
sudo cp health-check-server /etc/health-check-server/
sudo systemctl restart health-check.service
```

### 5. На VPS - протестируйте

```bash
curl -X POST http://localhost:8001/mqtt \
  -H "Content-Type: application/json" \
  -d '{"gate":"gate1"}'
```

Должен вернуться ответ "OK" (не "Method not allowed").

## Важные примечания

- **Обязательно сохраните файл на Windows** перед копированием (Ctrl+S)
- **Подтвердите замену файла** при копировании через MobaXterm
- **Проверьте содержимое файла** на VPS после копирования с помощью `verify-main-go.sh`

Если после всех шагов всё ещё не работает - покажите вывод команд `verify-main-go.sh` и `check-compiled-binary.sh`.
