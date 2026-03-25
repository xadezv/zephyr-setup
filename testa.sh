#!/bin/bash
# Лабораторная работа 2 — Zephyr OS: Stack Overflow & GDB


# ============================================================
# ЧАСТЬ 1 — Создание проекта
# ============================================================


# 1. Создание структуры проекта
cd ~/zephyrproject
mkdir -p apps/lab_stack_overflow/src
cd apps/lab_stack_overflow
# Создаёт папку проекта и поддиректорию src


# 2. Создание CMakeLists.txt
nano CMakeLists.txt
# Файл сборки CMake — указывает Zephyr где искать исходники

+ cmake_minimum_required(VERSION 3.20.0)
+
+ find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
+ project(lab_stack_overflow)
+
+ target_sources(app PRIVATE src/main.c)


# 3. Создание конфигурации проекта
nano prj.conf
# Включает консоль, printk и оптимизацию для отладки

+ CONFIG_CONSOLE=y
+ CONFIG_PRINTK=y
+ CONFIG_DEBUG_OPTIMIZATIONS=y


# 4. Создание main.c с уязвимостью
cd src
nano main.c
# Программа с намеренной уязвимостью — переполнение стека через strcpy

+ #include <zephyr/kernel.h>
+ #include <zephyr/sys/printk.h>
+ #include <string.h>
+
+ static void process_command(const char *cmd)
+ {
+     char buf[32];
+     strcpy(buf, cmd);
+     printk("Processing command: %s\n", buf);
+ }
+
+ void main(void)
+ {
+     printk("Lab: Ammateur ASSM and Zephyr started pack be like......\n");
+     const char *long_cmd = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
+     process_command(long_cmd);
+ }


# 5. Сборка проекта
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow
# Собирает проект с нуля для симулятора native_sim


# 6. Запуск (может выдать FATAL_ERROR — это нормально)
west build -t run
# Запускает скомпилированный образ Zephyr в симуляторе


# ============================================================
# GDB — отладка и дизассемблирование
# ============================================================


# 7. Проверка наличия zephyr.exe
cd ~/zephyrproject/build
ls zephyr/
# Убеждаемся что файл zephyr.exe существует


# 8. Запуск GDB
gdb zephyr/zephyr.exe
# Запускает отладчик GNU для анализа скомпилированного образа


# 9. Запуск программы внутри GDB
run
# Запускает программу — нажать "y" для подтверждения


# 10. Backtrace — стек вызовов (Ctrl+C перед этим)
bt
# Показывает какие функции были в стеке в момент остановки


# 11. Значения регистров
info registers
# Выводит значения всех регистров процессора


# 12. Дизассемблирование (ПЕРВЫЙ вариант — без canary)
disas process_command
# Выводит ассемблерный код функции — сохрани скрин для сравнения!


# Выход из GDB
quit


# ============================================================
# ЧАСТЬ 1.2 — Добавление Stack Canaries
# ============================================================


# 13. Изменить prj.conf — добавить защиту стека
cd ~/zephyrproject/apps/lab_stack_overflow
nano prj.conf
# CONFIG_NO_OPTIMIZATIONS отключает оптимизации, CONFIG_STACK_CANARIES добавляет канарейку

+ CONFIG_CONSOLE=y
+ CONFIG_PRINTK=y
+ CONFIG_NO_OPTIMIZATIONS=y
+ CONFIG_STACK_CANARIES=y


# 14. Пересборка с canary
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow
# Собирает проект с новой конфигурацией


# 15. Запуск
west build -t run


# 16. Снова GDB + дизассемблирование (ВТОРОЙ вариант — с canary)
cd ~/zephyrproject/build
gdb zephyr/zephyr.exe
disas process_command
# Сравни с шагом 12 — появятся инструкции проверки канарейки __stack_chk_guard


# ============================================================
# ЧАСТЬ 2 — Устранение уязвимости
# ============================================================


# 17. Изменить main.c — убрать уязвимость
nano ~/zephyrproject/apps/lab_stack_overflow/src/main.c
# Заменяем strcpy на strncpy + проверка длины

+ static void process_command(const char *cmd)
+ {
+     char buf[32];
+     size_t max_len = sizeof(buf) - 1;
+     size_t len = strlen(cmd);
+
+     if (len > max_len) {
+         printk("ERROR: command too long\n");
+         return;
+     }
+
+     strncpy(buf, cmd, max_len);
+     buf[max_len] = '\0';
+     printk("Processing command: %s\n", buf);
+ }


# 18. Финальная сборка и запуск
cd ~/zephyrproject
west build -p always -b native_sim apps/lab_stack_overflow
west build -t run
# Собираем и запускаем исправленную программу


# 19. Финальный GDB — дизассемблирование для сравнения
cd ~/zephyrproject/build
gdb zephyr/zephyr.exe
disas process_command
# Сравниваем все 3 варианта ассемблерного кода
