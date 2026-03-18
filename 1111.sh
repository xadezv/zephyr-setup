#!/bin/bash
# Лабораторная работа 2 — Zephyr Stack Overflow (полный автомат)

set -e

cd ~/zephyrproject
source .venv/bin/activate

# Шаг 1: Создание директории приложения
mkdir -p apps/lab_stack_overflow/src
cd apps/lab_stack_overflow

# Шаг 2: CMakeLists.txt
cat > CMakeLists.txt << 'CMAKE'
cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(lab_stack_overflow)
target_sources(app PRIVATE src/main.c)
CMAKE

# Шаг 3: prj.conf (без защиты)
cat > prj.conf << 'CONF'
CONFIG_CONSOLE=y
CONFIG_PRINTK=y
CONFIG_DEBUG_OPTIMIZATIONS=y
CONF

# Шаг 4: main.c с уязвимостью
cat > src/main.c << 'MAINCI'
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>
#include <string.h>

static void process_command(const char *cmd)
{
    char buf[32];
    strcpy(buf, cmd);
    printk("Processing command: %s\n", buf);
}

void main(void)
{
    printk("Lab: Amateur ASSM and Zephyr started\n");
    const char *long_cmd = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    process_command(long_cmd);
}
MAINCI

# Шаг 5: Сборка уязвимой версии
echo "=== Сборка уязвимой версии (без защиты) ==="
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow 2>&1 | tail -5

# Шаг 6: Запуск — ожидаем FATAL_ERROR или crash
echo "=== Запуск уязвимой программы ==="
timeout 5 west build -t run 2>&1 || echo "[FATAL_ERROR — ожидаемое переполнение буфера]"

# Шаг 7: GDB анализ уязвимой версии
echo "=== GDB анализ БЕЗ защиты ==="
cd ~/zephyrproject/build
ls zephyr/zephyr.exe
gdb -q \
  -ex "set pagination off" \
  -ex "run" \
  -ex "bt" \
  -ex "info registers" \
  -ex "disas process_command" \
  -ex "quit" \
  zephyr/zephyr.exe 2>&1 || true

# Шаг 8: Включаем Stack Canaries
echo "=== Включаем Stack Canaries ==="
cat > ~/zephyrproject/apps/lab_stack_overflow/prj.conf << 'CONF'
CONFIG_CONSOLE=y
CONFIG_PRINTK=y
CONFIG_NO_OPTIMIZATIONS=y
CONFIG_STACK_CANARIES=y
CONF

# Шаг 9: Пересборка с защитой
echo "=== Сборка с Stack Canaries ==="
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow 2>&1 | tail -5
timeout 5 west build -t run 2>&1 || echo "[Программа завершена — canary сработал]"

# Шаг 10: GDB анализ с защитой
echo "=== GDB анализ С защитой (Stack Canaries) ==="
cd ~/zephyrproject/build
gdb -q \
  -ex "set pagination off" \
  -ex "disas process_command" \
  -ex "quit" \
  zephyr/zephyr.exe 2>&1 || true

# Шаг 11: Безопасная версия main.c
echo "=== Устранение уязвимости ==="
cat > ~/zephyrproject/apps/lab_stack_overflow/src/main.c << 'MAINCI'
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>
#include <string.h>

static void process_command(const char *cmd)
{
    char buf[32];
    size_t max_len = sizeof(buf) - 1;
    size_t len = strlen(cmd);

    if (len > max_len) {
        printk("ERROR: command too long\n");
        return;
    }
    strncpy(buf, cmd, max_len);
    buf[max_len] = '\0';
    printk("Processing command: %s\n", buf);
}

void main(void)
{
    printk("Lab: Amateur ASSM and Zephyr started\n");
    const char *long_cmd = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    process_command(long_cmd);
}
MAINCI

# Шаг 12: Финальная сборка с исправленным кодом
echo "=== Финальная сборка — безопасная версия ==="
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow 2>&1 | tail -5
west build -t run 2>&1 || true

echo ""
echo "=== Лабораторная работа 2 выполнена полностью ==="
