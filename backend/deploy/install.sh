#!/usr/bin/env bash
# Maktab serverini yangi Ubuntu mashinasiga o'rnatadi -- boshidan oxirigacha.
#
#   sudo bash deploy/install.sh
#
# Qayta ishga tushirish xavfsiz: har qadam avval tekshiradi. Ya'ni bu ayni
# paytda yangilash yo'li ham -- `git pull` dan keyin shu skriptni qayta
# ishga tushirsangiz, yangi kod yig'iladi va xizmat qayta ko'tariladi.
#
# Ataylab qilmaydigan ishlari:
#   * mavjud .env ni ustiga yozmaydi -- ichida kalitlar bor
#   * bazaga tegmaydi
#   * eski serverni to'xtatmaydi -- buni siz, tekshirib bo'lgach qilasiz

set -euo pipefail

TARGET_DIR="/opt/smartschool"
APP_DIR="$TARGET_DIR/backend"
SERVICE_NAME="smartschool-school"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m    %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m    %s\033[0m\n' "$*"; }
die()  { printf '\n\033[31mXATO: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "sudo bilan ishga tushiring:  sudo bash deploy/install.sh"

# Skriptni chaqirgan haqiqiy foydalanuvchi -- papka oxirida shunga beriladi,
# aks holda hamma narsa root'niki bo'lib qoladi va keyin har buyruqqa sudo
# kerak bo'ladi.
REAL_USER="${SUDO_USER:-root}"

# --------------------------------------------------------------------------
# 0. Ombor to'g'ri joyda turibdimi
# --------------------------------------------------------------------------
# Klon boshqa papkaga tushgan bo'lishi mumkin (masalan /otp/ deb xato
# yozilgan). systemd xizmati aniq yo'lni kutadi, shuning uchun ko'chiramiz.
#
# Ko'chirishni skriptning o'zi turgan papkadan turib qilib bo'lmaydi -- fayl
# oyoq ostidan siljib ketadi. Shuning uchun avval /tmp ga nusxa olib, o'sha
# yerdan qayta ishga tushamiz.
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)"

if [[ "$REPO_ROOT" != "$TARGET_DIR" ]]; then
    if [[ "${SMARTFLOW_RELOCATING:-}" != "1" ]]; then
        cp "$SCRIPT_PATH" /tmp/smartflow-install.sh
        export SMARTFLOW_RELOCATING=1
        export SMARTFLOW_REPO_ROOT="$REPO_ROOT"
        exec bash /tmp/smartflow-install.sh "$@"
    fi

    REPO_ROOT="${SMARTFLOW_REPO_ROOT:?}"
    say "Omborni $TARGET_DIR ga ko'chirish"
    [[ -e "$TARGET_DIR" ]] && die "$TARGET_DIR allaqachon mavjud -- qo'lda hal qiling"
    mv "$REPO_ROOT" "$TARGET_DIR"
    ok "$REPO_ROOT -> $TARGET_DIR"
fi

[[ -f "$APP_DIR/docker-compose.yml" ]] || die "$APP_DIR da docker-compose.yml topilmadi"
cd "$APP_DIR"

# --------------------------------------------------------------------------
# 1. Docker
# --------------------------------------------------------------------------
say "Docker"
# curl Docker o'rnatgichning o'zi uchun kerak, shuning uchun undan oldin.
if ! command -v curl >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq curl
fi

if command -v docker >/dev/null 2>&1; then
    ok "allaqachon o'rnatilgan: $(docker --version)"
else
    curl -fsSL https://get.docker.com | sh
    ok "o'rnatildi: $(docker --version)"
fi

docker compose version >/dev/null 2>&1 \
    || die "docker compose topilmadi -- 'apt install -y docker-compose-v2' ni sinab ko'ring"

systemctl enable --now docker >/dev/null 2>&1 || true
ok "docker xizmati: $(systemctl is-active docker)"

# Foydalanuvchini docker guruhiga qo'shamiz, shunda keyin sudo kerak bo'lmaydi.
# Bu faqat keyingi kirishdan boshlab ta'sir qiladi -- shuning uchun skriptning
# o'zi baribir root sifatida ishlayveradi.
if [[ "$REAL_USER" != "root" ]] && ! id -nG "$REAL_USER" | grep -qw docker; then
    usermod -aG docker "$REAL_USER"
    warn "$REAL_USER docker guruhiga qo'shildi -- ta'sir qilishi uchun qaytadan kiring"
fi

# --------------------------------------------------------------------------
# 2. .env
# --------------------------------------------------------------------------
say ".env"
if [[ -f .env ]]; then
    ok "allaqachon bor -- tegilmadi"
    PORT="$(grep -E '^SCHOOL_SERVER_PORT=' .env | cut -d= -f2 | tr -d ' ')"
    PORT="${PORT:-8000}"
else
    command -v openssl >/dev/null 2>&1 || { apt-get update -qq; apt-get install -y -qq openssl; }

    echo "Bir necha savol. Bo'sh qoldirsangiz qavs ichidagi qiymat olinadi."
    echo

    read -rp "  Ochiq server manzili (masalan http://64.188.67.36:8200): " PUBLIC_URL
    read -rp "  Ochiq server kaliti (bootstrap_school.py chiqargan)     : " PUBLIC_KEY
    read -rp "  Direktor logini [director@smartschool.com]              : " ADMIN_EMAIL
    read -rp "  Direktor paroli  [tasodifiy yaratiladi]                 : " ADMIN_PASS
    read -rp "  Server porti [8000]                                     : " PORT

    ADMIN_EMAIL="${ADMIN_EMAIL:-director@smartschool.com}"
    PORT="${PORT:-8000}"

    # Port band bo'lsa oldindan aytamiz. Konteyner host tarmog'ida ishlaydi,
    # ya'ni bandlikni chetlab o'tolmaydi -- ilova ko'tarilmaydi yoki, undan
    # ham yomoni, telefon boshqa xizmatga ulanib "404" oladi.
    if ss -tlnH "sport = :$PORT" 2>/dev/null | grep -q .; then
        warn "$PORT porti allaqachon band -- boshqasini tanlang yoki egasini to'xtating"
    fi

    # Manzil oxiridagi ortiqcha belgilar -- nusxalashda tez-tez qo'shilib
    # qoladi va sinxronizatsiya jimgina ishlamay turadi.
    PUBLIC_URL="$(printf '%s' "$PUBLIC_URL" | tr -d ' ' | sed 's:/*$::')"

    umask 077
    cat > .env <<EOF
# $(date '+%Y-%m-%d') da deploy/install.sh yaratgan.
# Bu fayl omborga tushmaydi va tushmasligi kerak.

POSTGRES_PASSWORD=$(openssl rand -hex 16)
SMARTSCHOOL_AUTH_SECRET=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -hex 32)
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_MINUTES=1440
LEFT_SCHOOL_AFTER_MINUTES=30
SCHOOL_SERVER_PORT=$PORT

# Birinchi direktor -- faqat bo'sh bazada ishlatiladi.
SMARTSCHOOL_ADMIN_EMAIL=$ADMIN_EMAIL
SMARTSCHOOL_ADMIN_PASSWORD=$ADMIN_PASS

PUBLIC_SERVER_URL=$PUBLIC_URL
PUBLIC_SERVER_API_KEY=$PUBLIC_KEY

# Ixtiyoriy -- eski serverdagi .env dan ko'chiring.
GEMINI_API_KEY=
SMS_PROVIDER=
SMS_ROBITA_LOGIN=
SMS_ROBITA_PASSWORD=
EOF
    chmod 600 .env
    ok "yaratildi (chmod 600)"
fi

# --------------------------------------------------------------------------
# 3. Yig'ish va ishga tushirish
# --------------------------------------------------------------------------
say "Konteynerlarni yig'ish"
warn "birinchi safar 5-10 daqiqa -- insightface va onnxruntime katta"
docker compose up -d --build

say "Kutish"
for _ in $(seq 1 60); do
    if curl -fsS -o /dev/null http://localhost:${PORT}/docs 2>/dev/null; then
        ok "server javob beryapti"
        break
    fi
    sleep 5
done

if ! curl -fsS -o /dev/null http://localhost:${PORT}/docs 2>/dev/null; then
    warn "server hali javob bermayapti. Jurnalni ko'ring:"
    warn "  docker compose logs --tail 50 app"
fi

# --------------------------------------------------------------------------
# 4. Kompyuter yonganda o'zi ko'tarilsin
# --------------------------------------------------------------------------
say "Avtomatik ishga tushish"
install -m 644 deploy/${SERVICE_NAME}.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
ok "$SERVICE_NAME yoqildi -- kompyuter yonganda o'zi ko'tariladi"

# --------------------------------------------------------------------------
# 5. Papkani egasiga qaytarish
# --------------------------------------------------------------------------
if [[ "$REAL_USER" != "root" ]]; then
    # .env ham shu foydalanuvchiniki bo'lib qoladi. Root'niki qilib qo'yish
    # xavfsizroq tuyuladi, lekin `docker compose` ni o'sha foydalanuvchi
    # ishga tushiradi va .env ni o'qiy olmay qoladi -- shunda maxfiy
    # kalitlarsiz ko'tarilishga urinib, ishga tushmaydi.
    chown -R "$REAL_USER":"$REAL_USER" "$TARGET_DIR"
    chmod 600 "$APP_DIR/.env"
fi

# --------------------------------------------------------------------------
# Xulosa
# --------------------------------------------------------------------------
say "Tayyor"
docker compose ps

cat <<'EOF'

Keyingi qadamlar:

  1. Direktor parolini bilib oling.
     .env da yozgan bo'lsangiz -- o'sha. Bo'sh qoldirgan bo'lsangiz:

         docker compose logs app | grep -A3 "BIRINCHI DIREKTOR"

  2. Ilovani ulang. Telefon serverni tarmoqda o'zi topishi kerak; topmasa:

         Танзимот -> Суроғаи сервер -> http://<shu-mashina-ip>:8000

     IP ni bilish uchun:  hostname -I

  3. Direktor sifatida kiring va parolni o'zgartiring.

  4. Ilova orqali kiriting: sinflar, o'qituvchilar, o'quvchilar (surat bilan),
     kamera va jadval.

  5. Hammasi ishlaganiga ishonch hosil qilgach, ESKI serverni to'xtating.
     Ikkalasi bir vaqtda ishlasa bitta kamerani tortqilaydi.

Kundalik buyruqlar:

     docker compose logs -f app       jurnal
     docker compose restart app       qayta ishga tushirish
     docker compose down              to'xtatish (baza saqlanadi)

EOF
