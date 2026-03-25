#!/bin/bash
# Лабораторная работа 2 — Zephyr OS: Stack Overflow & GDB

# =============================================================
# ЧАСТЬ 1 — Создание проекта и сборка
# =============================================================

# 1. Переход в рабочую директорию и создание структуры проекта
cd ~/zephyrproject
mkdir -p apps/lab_stack_overflow/src
cd apps/lab_stack_overflow
# Создаёт папку проекта и поддиректорию src для исходных файлов

# 2. Создание CMakeLists.txt
nano CMakeLists.txt
# НАДО ВСТАВИТЬ:
# cmake_minimum_required(VERSION 3.20.0)
# find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
# project(lab_stack_overflow)
# target_sources(app PRIVATE src/main.c)
# Описание: файл сборки CMake, указывает Zephyr где искать исходники

# 3. Создание файла конфигурации проекта
nano prj.conf
# НАДО ВСТАВИТЬ:
# CONFIG_CONSOLE=y
# CONFIG_PRINTK=y
# CONFIG_DEBUG_OPTIMIZATIONS=y
# Описание: включает консоль, printk и оптимизацию для отладки

# 4. Переход в папку src и создание main.c
cd src
nano main.c
# НАДО ВСТАВИТЬ:
# #include <zephyr/kernel.h>
# #include <zephyr/sys/printk.h>
# #include <string.h>
#
# static void process_command(const char *cmd)
# {
#     char buf[32];
#     strcpy(buf, cmd);   // УЯЗВИМОСТЬ: нет проверки длины!
#     printk("Processing command: %s\n", buf);
# }
#
# void main(void)
# {
#     printk("Lab: Ammateur ASSM and Zephyr started pack be like......\n");
#     const char *long_cmd = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
#     process_command(long_cmd);
# }
# Описание: программа с намеренной уязвимостью — переполнение стека через strcpy без проверки длины

# 5. Сборка проекта
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow
# Описание: собирает проект с нуля (-p always) для симулятора native_sim

# 6. Запуск (может выдать FATAL_ERROR — это нормально)
west build -t run
# Описание: запускает скомпилированный образ Zephyr в симуляторе

# =============================================================
# GDB — отладка и дизассемблирование
# =============================================================

# 7. Проверка наличия zephyr.exe
cd ~/zephyrproject/build
ls zephyr/
# Описание: убеждаемся что файл zephyr.exe существует в папке сборки

# 8. Запуск GDB
gdb zephyr/zephyr.exe
# Описание: запускает отладчик GNU для анализа скомпилированного образа

# --- Команды внутри GDB ---

# 9. (gdb) run
# run
# Описание: запускает программу в GDB; нажать "y" для подтверждения

# 10. (gdb) bt — backtrace
# bt
# Описание: показывает стек вызовов функций в момент остановки (Ctrl+C перед этим)

# 11. (gdb) info registers
# info registers
# Описание: выводит значения всех регистров процессора в текущий момент

# 12. (gdb) disas — дизассемблирование функции
# disas process_command
# Описание: выводит ассемблерный код функции process_command (ПЕРВЫЙ вариант без canary)

# Выход из GDB: quit или Ctrl+D

# =============================================================
# ЧАСТЬ 1.2 — Добавление Stack Canaries
# =============================================================

# 13. Вернуться в папку проекта (из GDB — Ctrl+Z или quit)
cd ~/zephyrproject/apps/lab_stack_overflow

# 14. Изменить prj.conf — добавить Stack Canaries
nano prj.conf
# НАДО ИЗМЕНИТЬ НА:
# CONFIG_CONSOLE=y
# CONFIG_PRINTK=y
# CONFIG_NO_OPTIMIZATIONS=y
# CONFIG_STACK_CANARIES=y
# Описание: CONFIG_NO_OPTIMIZATIONS отключает оптимизации (лучше видно в asm),
#           CONFIG_STACK_CANARIES включает защиту стека — добавляет канарейку

# 15. Пересборка
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow
# Описание: пересобирает проект с новой конфигурацией (с canary)

# 16. Запуск
west build -t run

# 17. Снова запуск GDB
cd ~/zephyrproject/build
gdb zephyr/zephyr.exe

# 18. (gdb) Дизассемблирование ВТОРОГО варианта
# disas process_command
# Описание: выводит ассемблерный код С canary — сравни с шагом 12!
# Отличие: появятся инструкции __stack_chk_guard (проверка канарейки)

# =============================================================
# ЧАСТЬ 2 — Устранение уязвимости
# =============================================================

# 19. Изменить main.c — убрать уязвимость
nano ~/zephyrproject/apps/lab_stack_overflow/src/main.c
# НАДО ЗАМЕНИТЬ ФУНКЦИЮ process_command НА:
# static void process_command(const char *cmd)
# {
#     char buf[32];
#     size_t max_len = sizeof(buf) - 1;
#     size_t len = strlen(cmd);
#     if (len > max_len) {
#         printk("ERROR: command too long\n");
#         return;
#     }
#     strncpy(buf, cmd, max_len);
#     buf[max_len] = '\0';
#     printk("Processing command: %s\n", buf);
# }
# Описание: теперь используется strncpy + проверка длины — уязвимость устранена

# 20. Финальная сборка и запуск
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow
west build -t run
# Описание: собираем и запускаем исправленную программу

# 21. Снова GDB + дизассемблирование для сравнения
cd ~/zephyrproject/build
gdb zephyr/zephyr.exe
# disas process_command
# Описание: смотрим финальный ассемблерный код — сравниваем все 3 варианта
