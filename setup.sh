#!/bin/bash
set -e

echo "=== Версия скрипта: v13 (2026-03-11) ==="

sudo timedatectl set-ntp true
sudo systemctl restart systemd-timesyncd 2>/dev/null || true
sleep 3
CURRENT_DATE=$(curl -s --head http://google.com 2>/dev/null | grep -i "^date:" | sed 's/[Dd]ate: //')
if [ -n "$CURRENT_DATE" ]; then
    sudo date -s "$CURRENT_DATE"
fi
sleep 1

sudo apt update && sudo apt install -y --no-install-recommends \
    git cmake ninja-build gperf ccache dfu-util device-tree-compiler \
    wget python3-dev python3-venv python3-tk xz-utils file make gcc \
    gcc-multilib g++-multilib libsdl2-dev libmagic1

sudo apt install -y python3.12-venv

sudo apt install -y wireshark tcpdump netcat-openbsd

rm -rf ~/zephyrproject/.venv
mkdir -p ~/zephyrproject
python3 -m venv ~/zephyrproject/.venv
source ~/zephyrproject/.venv/bin/activate

pip install west

if [ ! -d ~/zephyrproject/.west ]; then
    west init ~/zephyrproject
fi
cd ~/zephyrproject
west update

west zephyr-export

west packages pip --install

cd ~/zephyrproject/zephyr
west sdk install

west build -b native_sim samples/net/sockets/echo_server \
    -DEXTRA_CONF_FILE=overlay-nsos.conf

echo ""
echo "=== Готово! Теперь открой 3 терминала: ==="
echo ""
echo "  [Терминал 1]:"
echo "    source ~/zephyrproject/.venv/bin/activate && cd ~/zephyrproject/zephyr && west build -t run"
echo ""
echo "  [Терминал 2]:"
echo "    ss -tnlp | grep zephyr"
echo "    sudo tcpdump -A -i lo port PORT"
echo ""
echo "  [Терминал 3]:"
echo "    nc 127.0.0.1 PORT"
echo "    Username=admin&password=Supersecret123"
echo "    I love Zephyr. Zephyr and ASSM forever"
