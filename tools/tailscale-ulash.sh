#!/usr/bin/env bash
# Maktab serverini Tailscale'ga ulash (masofadan SSH uchun).
#
# Ishlatish (kompyuter oldidagi odam bitta qator yozadi):
#   sudo bash ~/smartschool/tools/tailscale-ulash.sh tskey-auth-XXXXXXXX
#
# Kalit (tskey-auth-...) Tailscale admin panelidan olinadi va bu faylga
# YOZILMAYDI -- faqat buyruqqa argument sifatida beriladi.
# Kalitsiz ishga tushirilsa, brauzer uchun login havolasini chiqaradi.
set -euo pipefail

HOSTNAME_TS="maktab-server"
KEY="${1:-}"

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

line() { echo "=================================================="; }

line; echo "  MAKTAB SERVERI -> TAILSCALE"; line

if ! command -v tailscale >/dev/null 2>&1; then
    echo "[1/3] Tailscale o'rnatilmoqda..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    echo "[1/3] Tailscale allaqachon o'rnatilgan."
fi

echo "[2/3] Xizmat ishga tushirilmoqda..."
systemctl enable --now tailscaled
systemctl enable --now ssh >/dev/null 2>&1 || true

echo "[3/3] Tailscale tarmog'iga ulanmoqda..."
if [ -n "$KEY" ]; then
    tailscale up --authkey="$KEY" --ssh --hostname="$HOSTNAME_TS" --reset
else
    echo
    echo ">>> Quyida chiqadigan HAVOLANI nusxalab, administratorga yuboring."
    echo ">>> U havolani ochib tasdiqlaguncha bu oyna kutib turadi."
    echo
    tailscale up --ssh --hostname="$HOSTNAME_TS" --reset
fi

IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
echo
line
if [ -n "$IP" ]; then
    echo "  TAYYOR!  Ulandi."
    echo "  Server nomi : $HOSTNAME_TS"
    echo "  Tailscale IP: $IP"
    echo
    echo "  Shu IP manzilni administratorga yuboring."
else
    echo "  ULANMADI. Quyidagi holatni administratorga yuboring:"
    tailscale status || true
fi
line
