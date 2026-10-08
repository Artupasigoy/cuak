#!/bin/bash
# cuak installer: idempoten, aman diulang. MEMAKSA dependensi terinstall.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
SUDO=""; [ "$(id -u)" = 0 ] || SUDO="sudo"
echo "[1/5] cek systemd..."; [ -d /run/systemd/system ] || { echo "FATAL: butuh systemd."; exit 1; }
echo "[2/5] paksa install dependensi (autossh, openssh-client, iputils-ping)..."
if command -v apt-get >/dev/null; then
  $SUDO apt-get update -q 2>&1 | tail -n1
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -q autossh openssh-client iputils-ping
elif command -v apk >/dev/null; then $SUDO apk add --no-cache autossh openssh-client iputils
elif command -v dnf >/dev/null; then $SUDO dnf install -y -q autossh openssh-clients iputils
elif command -v pacman >/dev/null; then $SUDO pacman -Sy --noconfirm --needed autossh openssh iputils
else echo "FATAL: package manager tak dikenal. Install manual: autossh openssh-client iputils-ping"; exit 1; fi
echo "[3/5] verifikasi paksa..."
for b in autossh ssh ping systemctl flock; do
  command -v "$b" >/dev/null || { echo "FATAL: $b tetap hilang setelah install."; exit 1; }
  echo "  ok: $b"
done
[ -f "$REPO/bin/cuak" ] || { echo "FATAL: file repo tak lengkap di $REPO. Clone dulu: git clone https://github.com/Artupasigoy/cuak"; exit 1; }
echo "[4/5] pasang file..."
$SUDO mkdir -p /usr/local/bin /usr/local/lib/cuak /etc/cuak/devices /etc/cuak/keys /var/log/cuak
$SUDO cp "$REPO/bin/cuak" /usr/local/bin/cuak
$SUDO cp "$REPO/lib/cuak-holder.sh" "$REPO/lib/cuak-watchdog.sh" /usr/local/lib/cuak/
$SUDO cp "$REPO/systemd/cuak-holder@.service" "$REPO/systemd/cuak-watchdog.service" "$REPO/systemd/cuak-watchdog.timer" /etc/systemd/system/
$SUDO chmod 755 /usr/local/bin/cuak /usr/local/lib/cuak/*.sh
$SUDO systemctl daemon-reload
$SUDO systemctl enable --now cuak-watchdog.timer
for u in $($SUDO systemctl list-units --plain --no-legend 'cuak-holder@*.service' 2>/dev/null | awk '$2=="active"{print $1}'); do
  echo "  restart $u (terapkan kode baru)"; $SUDO systemctl restart "$u"
done
echo "[5/5] doctor:"; $SUDO /usr/local/bin/cuak doctor || true
echo "SELESAI. Jalankan: sudo cuak"
