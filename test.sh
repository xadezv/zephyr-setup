#!/bin/bash
# ОИБ Практика 4 — Разграничение прав доступа

echo "=== 1. Получение прав root ==="
echo "Команда: sudo su"

echo ""
echo "=== 2. Создание пользователя sit2 ==="
sudo useradd -m -d /home/sit2 sit2
echo "Установка пароля: passwd sit2"

echo ""
echo "=== 3. ID пользователей ==="
id sit
id sit2

echo ""
echo "=== 4. Права на домашние каталоги ==="
ls -la /home/sit 2>/dev/null || echo "/home/sit не существует"
ls -la /home/sit2

echo ""
echo "=== 5. Создание файла с маской 0077 (под sit2) ==="
echo "Переключись на sit2: su sit2"
echo "umask 0077"
echo "echo 'hello' > ~/testfile"

echo ""
echo "=== 6. Чтение файла под sit (должен отказать) ==="
echo "cat /home/sit2/testfile"

echo ""
echo "=== 7. Изменение прав — sit может писать но не читать ==="
echo "chmod o+w,o-r /home/sit2/testfile"

echo ""
echo "=== 8. Запись текста под sit ==="
echo "echo 'текст от sit' >> /home/sit2/testfile"

echo ""
echo "=== 9. Проверка прав и чтение под sit2 ==="
echo "ls -l ~/testfile"
echo "cat ~/testfile"

echo ""
echo "=== 10. Каталог под sit2 с правами записи для группы ==="
echo "mkdir ~/mydir"
echo "chmod g+w ~/mydir"

echo ""
echo "=== 11. Добавление sit в группу sit2 ==="
sudo usermod -aG sit2 sit 2>/dev/null && echo "sit добавлен в группу sit2" || echo "usermod выполнить от root"
groups sit

echo ""
echo "=== 12. Создание файлов в каталоге sit2 под пользователем sit ==="
echo "touch /home/sit2/mydir/file1 /home/sit2/mydir/file2"

echo ""
echo "=== 13. Удаление sit2 ==="
echo "sudo userdel -r sit2"

echo ""
echo "=== ГОТОВО ==="
