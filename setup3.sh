#!/bin/bash
set -e

echo "=== Версия скрипта: setup3-v1 (2026-03-10) — полный сброс и пересборка ==="

echo "=== Шаг 1: Сносим старый zephyrproject ==="
deactivate 2>/dev/null || true
rm -rf ~/zephyrproject

echo "=== Шаг 2: Создаём виртуальное окружение ==="
mkdir -p ~/zephyrproject
python3 -m venv ~/zephyrproject/.venv
source ~/zephyrproject/.venv/bin/activate

echo "=== Шаг 3: Установка west ==="
pip install west

echo "=== Шаг 4: Инициализация Zephyr ==="
west init ~/zephyrproject
cd ~/zephyrproject
west update --narrow -o=--depth=1

echo "=== Шаг 5: Экспорт CMake ==="
west zephyr-export

echo "=== Шаг 6: Python-зависимости ==="
west packages pip --install

echo "=== Шаг 7: Установка SDK ==="
cd ~/zephyrproject/zephyr
west sdk install

echo "=== Шаг 8: Сборка echo_server ==="
west build -b native_sim samples/net/sockets/echo_server \
    -DEXTRA_CONF_FILE=overlay-nsos.conf

echo ""
echo "=== Готово! Теперь открой 3 терминала: ==="
echo ""
echo "  [Терминал 1 — запуск сервера]:"
echo "    source ~/zephyrproject/.venv/bin/activate && cd ~/zephyrproject/zephyr && west build -t run"
echo ""
echo "  [Терминал 2 — перехватчик]:"
echo "    ss -tnlp | grep zephyr        # узнать PORT"
echo "    sudo tcpdump -A -i lo port PORT"
echo ""
echo "  [Терминал 3 — клиент]:"
echo "    nc 127.0.0.1 PORT"
echo "    Введи: Username=admin&password=Supersecret123"
echo "    Введи: I love Zephyr. Zephyr and ASSM forever"
