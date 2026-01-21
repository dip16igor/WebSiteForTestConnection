@echo off
REM Скрипт для деплоя health-check-server на VPS с Windows
REM Использование: deploy-from-windows.bat <VPS_IP>

echo ================================================
echo Деплой health-check-server на VPS
echo ================================================
echo.

IF "%1"=="" (
    echo ОШИБКА: Не указан IP-адрес VPS!
    echo Использование: %~nx0
    echo Пример: %~nx0 192.168.1.100
    echo.
    echo Пожалуйста, укажите IP-адрес VPS как первый параметр.
    pause
    exit /b 1
)

set VPS_IP=%1

echo.
echo IP-адрес VPS: %VPS_IP%
echo.

REM Проверка наличия файлов
IF NOT EXIST "main.go" (
    echo ОШИБКА: Файл main.go не найден в текущей директории!
    echo Пожалуйста, убедитесь, что вы находитесь в директории проекта.
    pause
    exit /b 1
)

IF NOT EXIST "config.yaml" (
    echo ОШИБКА: Файл config.yaml не найден в текущей директории!
    pause
    exit /b 1
)

echo.
echo Файлы найдены. Начинаю копирование...
echo.

REM Копирование файлов через SCP
echo Копирование main.go...
scp main.go dip16@%VPS_IP%:/tmp/health-check-deploy/
IF %ERRORLEVEL% NEQ 0 (
    echo ОШИБКА при копировании main.go!
    pause
    exit /b 1
)
echo ✓ main.go скопирован

echo.
echo Копирование config.yaml...
scp config.yaml dip16@%VPS_IP%:/tmp/health-check-deploy/
IF %ERRORLEVEL% NEQ 0 (
    echo ОШИБКА при копировании config.yaml!
    pause
    exit /b 1
)
echo ✓ config.yaml скопирован

echo.
echo Копирование скрипта деплоя...
scp deploy-mux-handle-fix.sh dip16@%VPS_IP%:/tmp/health-check-deploy/
IF %ERRORLEVEL% NEQ 0 (
    echo ОШИБКА при копировании скрипта деплоя!
    pause
    exit /b 1
)
echo ✓ Скрипт деплоя скопирован

echo.
echo ================================================
echo Файлы скопированы на VPS. Выполняю деплой...
echo ================================================
echo.

REM Выполнение деплоя на VPS через SSH
echo Подключение к VPS и выполнение деплоя...
ssh dip16@%VPS_IP% "cd /tmp/health-check-deploy && bash deploy-mux-handle-fix.sh"
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo ОШИБКА при выполнении деплоя на VPS!
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================
echo Деплой завершён!
echo ================================================
echo.
echo Приложение запущено на порту 8001
echo.
echo MQTT эндпоинт доступен по адресу: http://%VPS_IP%:8001/mqtt
echo.
echo Примеры использования:
echo.
echo Тест health check:
echo   curl http://%VPS_IP%:8001/
echo.
echo Тест MQTT (gate1):
echo   curl -X POST http://%VPS_IP%:8001/mqtt -H "Content-Type: application/json" -d "{\"gate\":\"gate1\"}"
echo.
echo Тест MQTT (gate2):
echo   curl -X POST http://%VPS_IP%:8001/mqtt -H "Content-Type: application/json" -d "{\"gate\":\"gate2\"}"
echo.
echo Просмотр логов:
echo   ssh dip16@%VPS_IP% "sudo journalctl -u health-check.service -f"
echo.
echo ================================================
echo.
pause
