#!/bin/bash
# cuak uninstall: hentikan semua holder, hapus unit+file (log & device ikut hapus).
set -euo pipefail
SUDO=""; [ "$(id -u)" = 0 ] || SUDO="sudo"
for c in /etc/cuak/devices/*.conf; do
  [ -f "$c" ] || continue
  a=$(basename "$c" .conf)
  $SUDO systemctl stop "cuak-holder@$a.service" 2>/dev/null || true
  $SUDO systemctl disable "cuak-holder@$a.service" 2>/dev/null || true
done
$SUDO systemctl stop cuak-watchdog.timer 2>/dev/null || true
$SUDO systemctl disable cuak-watchdog.timer 2>/dev/null || true
$SUDO rm -f /usr/local/bin/cuak /usr/local/lib/cuak/*.sh /etc/systemd/system/cuak-holder@.service /etc/systemd/system/cuak-watchdog.*
$SUDO rm -rf /etc/cuak /var/log/cuak
$SUDO systemctl daemon-reload
echo "cuak ter-uninstall bersih."
