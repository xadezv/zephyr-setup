#!/bin/bash
# ОИБ Практика 4 — Разграничение прав доступа
# Запускать пошагово, не весь скрипт сразу!

# === ШАГ 1: Получить права root ===
sudo su

# === ШАГ 2: Создать пользователя sit2 ===
useradd -m -d /home/sit2 sit2
passwd sit2

# === ШАГ 3: Выйти из root ===
exit

# === ШАГ 4: Проверить ID ===
id sit
id sit2

# === ШАГ 5: Права на домашние каталоги ===
ls -la /home/sit
ls -la /home/sit2

# === ШАГ 6: Под пользователем sit2 — создать файл с маской 0077 ===
su sit2
umask 0077
echo "hello" > ~/testfile
exit

# === ШАГ 7: Под пользователем sit — попробовать прочитать (должен отказать) ===
su sit
cat /home/sit2/testfile

# === ШАГ 8: Под root — изменить права (sit может писать, но не читать) ===
exit
sudo chmod o+w,o-r /home/sit2/testfile

# === ШАГ 9: Под sit — записать текст через nano ===
su sit
nano /home/sit2/testfile
exit

# === ШАГ 10: Под sit2 — проверить права и прочитать файл ===
su sit2
ls -l ~/testfile
cat ~/testfile

# === ШАГ 11: Создать каталог и дать группе права на запись ===
mkdir ~/mydir
chmod g+w ~/mydir
exit

# === ШАГ 12: Под root — добавить sit в группу sit2 ===
sudo usermod -aG sit2 sit

# === ШАГ 13: Проверить группы пользователя sit ===
groups sit

# === ШАГ 14: Под sit — создать файлы в каталоге sit2 ===
su sit
touch /home/sit2/mydir/file1
touch /home/sit2/mydir/file2
exit

# === ШАГ 15: Под root — удалить sit2 вместе с домашним каталогом ===
sudo userdel -r sit2
