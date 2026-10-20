#!/usr/bin/env bash
# Maktab serverini PUBLIC serverga teskari SSH tunnel bilan ulash.
# Maktab serveri o'zi tashqariga chiqib ulanadi -- maktab tarmog'ida port
# ochilmaydi. Tunnel systemd xizmati: uzilsa o'zi qayta ulanadi, server qayta
# yoqilganda ham ishlaydi.
#
# Ishlatish (maktab serverida):
#   sudo bash /opt/smartschool/tools/tunnel-ochish.sh
#
# Keyin ekrandagi KALITNI public serverdagi /root/.ssh/authorized_keys ga
# qo'shasiz va public serverdan kirasiz:
#   ssh -p 2222 proxyserver@localhost
set -euo pipefail

PUBLIC_HOST="64.188.67.36"
PUBLIC_USER="root"
REMOTE_PORT="2222"
KEY="/root/.ssh/smartflow_tunnel"
UNIT="/etc/systemd/system/smartflow-tunnel.service"

if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

line() { echo "=================================================="; }

mkdir -p /root/.ssh && chmod 700 /root/.ssh
if [ ! -f "$KEY" ]; then
    ssh-keygen -t ed25519 -N "" -C "smartflow-tunnel@$(hostname)" -f "$KEY" >/dev/null
fi

cat > "$UNIT" <<EOF
[Unit]
Description=SmartFlow reverse SSH tunnel to public server
After=network-online.target ssh.service
Wants=network-online.target

[Service]
ExecStart=/usr/bin/ssh -N -i $KEY \\
  -o StrictHostKeyChecking=accept-new \\
  -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \\
  -o ExitOnForwardFailure=yes \\
  -R 127.0.0.1:$REMOTE_PORT:localhost:22 \\
  $PUBLIC_USER@$PUBLIC_HOST
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ssh >/dev/null 2>&1 || true
systemctl enable smartflow-tunnel >/dev/null
systemctl restart smartflow-tunnel

sleep 5
line
echo "  TUNNEL SOZLANDI"
line
echo "Quyidagi KALIT qatorini administratorga yuboring (bitta uzun qator):"
echo
cat "$KEY.pub"
echo
line
echo "Tunnel holati: $(systemctl is-active smartflow-tunnel)"
echo "(Kalit public serverga qo'shilmaguncha 'activating' bo'lib turadi --"
echo " qo'shilgach 15 soniya ichida o'zi ulanadi.)"
line
