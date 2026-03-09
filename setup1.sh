#!/bin/bash
set -e

echo "=== Версия скрипта: setup1-v3 (2026-03-09) — без установки SDK ==="

echo "=== Шаг 1: Активация виртуального окружения ==="
source ~/zephyrproject/.venv/bin/activate

echo "=== Шаг 2: Экспорт Zephyr CMake ==="
cd ~/zephyrproject
west zephyr-export

echo "=== Шаг 3: Установка Python-зависимостей ==="
west packages pip --install

echo "=== Шаг 4: Сборка echo_server для native_sim ==="
cd ~/zephyrproject/zephyr
west build -b native_sim samples/net/sockets/echo_server \
    --DEXTRA_CONF_FILE=overlay-nsos.conf

echo ""
echo "=== Готово! Теперь открой 3 терминала: ==="
echo ""
echo "  [Терминал 1 — запуск сервера]:"
echo "    cd ~/zephyrproject/zephyr && west build -t run"
echo ""
echo "  [Терминал 2 — перехватчик]:"
echo "    ss -tnlp | grep zephyr        # узнать PORT"
echo "    sudo tcpdump -A -i lo port PORT"
echo ""
echo "  [Терминал 3 — клиент]:"
echo "    nc 127.0.0.1 PORT"
echo "    Введи: Username=admin&password=Supersecret123"
echo "    Введи: I love Zephyr. Zephyr and ASSM forever"
echo ""
echo "  Зайди в Терминал 2 и увидишь перехваченные данные."
