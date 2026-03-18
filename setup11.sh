#!/bin/bash
# Лабораторная работа 2 — Zephyr Stack Overflow

# Шаг 1: Создание директории приложения
cd ~/zephyrproject
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
cat > src/main.c << 'MAinc'
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

# Шаг 5: Сборка и запуск (ожидаем FATAL_ERROR)
cd ~/zephyrproject
source .venv/bin/activate
west build -p always -b native_sim apps/lab_stack_overflow
west build -t run || true

# Шаг 6: Анализ в GDB
cd ~/zephyrproject/build
ls zephyr/zephyr.exe
echo "--- Запускаем GDB ---"
echo -e "run\nbt\ninfo registers\ndisas process_command\nquit" | gdb -q zephyr/zephyr.exe

# Шаг 7: Включаем Stack Canaries
cd ~/zephyrproject/apps/lab_stack_overflow
cat > prj.conf << 'CONF'
CONFIG_CONSOLE=y
CONFIG_PRINTK=y
CONFIG_NO_OPTIMIZATIONS=y
CONFIG_STACK_CANARIES=y
CONF

# Шаг 8: Пересборка с защитой
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow
west build -t run || true

# Шаг 9: GDB с защитой — смотрим отличия
cd ~/zephyrproject/build
echo -e "disas process_command\nquit" | gdb -q zephyr/zephyr.exe

# Шаг 10: Устранение уязвимости — безопасный main.c
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

# Шаг 11: Финальная сборка с исправленным кодом
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow
west build -t run

echo "=== Лабораторная работа 2 выполнена ==="
