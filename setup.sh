#!/bin/bash
set -e

echo "=== Версия скрипта: v9 (2026-03-09) ==="

echo "=== Шаг 0: Синхронизация времени (фикс ошибок репозитория) ==="
sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd 2>/dev/null || true
sleep 3
CURRENT_DATE=$(curl -s --head http://google.com 2>/dev/null | grep -i "^date:" | sed 's/[Dd]ate: //')
if [ -n "$CURRENT_DATE" ]; then
    sudo date -s "$CURRENT_DATE" && echo "Время синхронизировано: $CURRENT_DATE"
else
    echo "Не удалось получить время автоматически. Установи вручную: sudo date -s 'YYYY-MM-DD HH:MM:SS'"
fi
sleep 1

echo "=== Шаг 1: Установка базовых утилит ==="
sudo apt update && sudo apt install -y --no-install-recommends \
    git cmake ninja-build gperf ccache dfu-util device-tree-compiler \
    wget python3-dev python3-pip python3-setuptools python3-tk \
    python3-wheel python3-venv xz-utils file make gcc gcc-multilib \
    g++-multilib libsdl2-dev libmagic1 wireshark tcpdump netcat-openbsd

echo "=== Шаг 2: Создание виртуального окружения ==="
rm -rf ~/zephyrproject/.venv
mkdir -p ~/zephyrproject
python3 -m venv ~/zephyrproject/.venv
source ~/zephyrproject/.venv/bin/activate

echo "=== Шаг 3: Установка west ==="
pip install west

echo "=== Шаг 4: Инициализация Zephyr проекта ==="
if [ ! -d ~/zephyrproject/.west ]; then
    west init ~/zephyrproject
else
    echo "Уже инициализирован, пропускаем west init"
fi
cd ~/zephyrproject
west update

echo "=== Шаг 5: Экспорт Zephyr CMake ==="
west zephyr-export

echo "=== Шаг 6: Установка Python-зависимостей ==="
west packages pip --install

echo "=== Шаг 7: Установка Zephyr SDK ==="
cd ~/zephyrproject/zephyr
west sdk install

echo "=== Шаг 8: Сборка echo_server для native_sim ==="
cd ~/zephyrproject/zephyr
west build -b native_sim samples/net/sockets/echo_server \
    --DEXTRA_CONF_FILE=overlay-nsos.conf

echo ""
echo "=== Готово! Теперь открой 3 терминала и выполни: ==="
echo ""
echo "  [Терминал 1 — сервер]:"
echo "    cd ~/zephyrproject/zephyr && west build -t run"
echo "    (запомни PORT который выдаст в консоли)"
echo ""
echo "  [Терминал 2 — перехватчик]:"
echo "    sudo tcpdump -i lo port PORT"
echo ""
echo "  [Терминал 3 — клиент]:"
echo "    nc localhost PORT"
echo "    Введи: I love Zephyr. Zephyr and ASSM forever"
echo ""
echo "  Зайди в Терминал 2 и увидишь перехваченные данные."
