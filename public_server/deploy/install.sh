#!/usr/bin/env bash
# First-time setup for the Public Server on a fresh Ubuntu machine.
#
#   sudo bash deploy/install.sh
#
# Safe to re-run: every step checks before it acts, so this doubles as the
# upgrade path after pulling new code.
#
# What it does NOT do, on purpose:
#   * write .env       -- it holds secrets; you fill it in
#   * request a TLS certificate -- needs the domain pointing here first
#   * touch the database contents

set -euo pipefail

APP_DIR="/opt/smartschool/public_server"
APP_USER="smartschool"
DB_NAME="smartschool_public"
DB_USER="smartschool"

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
    echo "sudo bilan ishga tushiring: sudo bash deploy/install.sh" >&2
    exit 1
fi

say "System packages"
apt-get update -qq
apt-get install -y -qq python3-venv python3-pip postgresql nginx

say "Service account"
if ! id -u "$APP_USER" >/dev/null 2>&1; then
    # No login shell and no home: this account exists to run one process.
    useradd --system --shell /usr/sbin/nologin --home-dir "$APP_DIR" "$APP_USER"
    echo "  foydalanuvchi yaratildi: $APP_USER"
else
    echo "  foydalanuvchi allaqachon bor: $APP_USER"
fi

say "Database"
if ! sudo -u postgres psql -tAc "select 1 from pg_roles where rolname='$DB_USER'" | grep -q 1; then
    DB_PASS="$(openssl rand -hex 24)"
    sudo -u postgres psql -qc "create role $DB_USER login password '$DB_PASS'"
    echo "  rol yaratildi. .env ga yozing:"
    echo "    DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost/$DB_NAME"
else
    echo "  rol allaqachon bor: $DB_USER (paroli o'zgartirilmadi)"
fi

if ! sudo -u postgres psql -tAc "select 1 from pg_database where datname='$DB_NAME'" | grep -q 1; then
    sudo -u postgres createdb -O "$DB_USER" "$DB_NAME"
    echo "  baza yaratildi: $DB_NAME"
else
    echo "  baza allaqachon bor: $DB_NAME"
fi

say "Python environment"
cd "$APP_DIR"
[[ -d venv ]] || python3 -m venv venv
./venv/bin/pip install -q --upgrade pip
./venv/bin/pip install -q -r requirements.txt
echo "  bog'liqliklar o'rnatildi"

if [[ ! -f .env ]]; then
    cp .env.example .env
    chmod 600 .env
    echo
    echo "  !!! .env yaratildi, LEKIN to'ldirilmagan."
    echo "  !!! nano $APP_DIR/.env  -- DATABASE_URL va SMARTSCHOOL_PUBLIC_AUTH_SECRET"
    echo "  !!! Maxfiy kalit uchun: openssl rand -hex 32"
fi

chown -R "$APP_USER:$APP_USER" "$APP_DIR"

say "systemd"
cp deploy/smartschool-public.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable smartschool-public >/dev/null
echo "  xizmat yoqildi (hali ishga tushirilmadi)"

cat <<'NEXT'

==> Qolgan qadamlar (qo'lda)

  1. .env ni to'ldiring:
       sudo nano /opt/smartschool/public_server/.env

  2. Xizmatni ishga tushiring. Jadvallar birinchi ishga tushishda
     o'zi yaratiladi (app/main.py dagi create_all + ensure_database_schema),
     alohida migratsiya buyrug'i kerak emas:
       sudo systemctl start smartschool-public
       sudo systemctl status smartschool-public

  3. Maktab kalitini yarating va uni maktab serveriga yozing:
       sudo -u smartschool /opt/smartschool/public_server/venv/bin/python \
            deploy/bootstrap_school.py "Maktab nomi"

  4. nginx va HTTPS:
       sudo cp deploy/nginx.conf /etc/nginx/sites-available/smartschool-public
       # domenni tahrirlang
       sudo ln -s /etc/nginx/sites-available/smartschool-public /etc/nginx/sites-enabled/
       sudo nginx -t && sudo systemctl reload nginx
       sudo apt install -y certbot python3-certbot-nginx
       sudo certbot --nginx -d SIZNING.DOMEN

  5. Tekshiring:
       curl https://SIZNING.DOMEN/

NEXT
