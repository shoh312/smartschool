#!/usr/bin/env bash
# Vaqtinchalik masofaviy kirish (tmate). Hisob, kalit, port ochish kerak emas.
#
# Kompyuter oldidagi odam yozadi:
#   bash /opt/smartschool/tools/ssh-ochish.sh
#
# Ekranda "ssh XXXX@...tmate.io" qatori chiqadi -- shuni administratorga
# SHAXSIY xabarda yuboradi. Oyna ochiq turguncha kirish ishlaydi;
# yopilsa (yoki Ctrl+C) kirish o'chadi.
set -euo pipefail

line() { echo "=================================================="; }

if ! command -v tmate >/dev/null 2>&1; then
    echo "tmate o'rnatilmoqda (parol so'ralsa -- kompyuter parolini yozing)..."
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tmate
fi

line
echo "  Bir necha soniyada pastda 'ssh session:' qatori chiqadi."
echo "  O'SHA QATORNI administratorga yuboring."
echo "  BU OYNANI YOPMANG -- yopilsa ulanish o'chadi."
line
echo

# -F: oldingi planda ishlaydi, ulanish qatorlarini chiqaradi va uzilsa qayta ulanadi
exec tmate -F
