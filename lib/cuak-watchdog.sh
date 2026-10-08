#!/bin/bash
# cuak watchdog: lapis terluar. Unit aktif tapi log diam >12 mnt = zombie -> restart.
for conf in /etc/cuak/devices/*.conf; do
  [ -f "$conf" ] || continue
  a=$(basename "$conf" .conf)
  unit="cuak-holder@$a.service"
  systemctl is-enabled -q "$unit" 2>/dev/null || continue
  if ! systemctl is-active -q "$unit"; then
    systemctl start "$unit" 2>/dev/null
    echo "$(date -u +%FT%TZ) [$a] watchdog: unit mati -> start" >>"/var/log/cuak/$a.log"
    continue
  fi
  log="/var/log/cuak/$a.log"
  [ -f "$log" ] || continue
  if [ "$(wc -l <"$log")" -gt 5000 ]; then tail -n 2000 "$log" >"$log.tmp" && mv "$log.tmp" "$log"; fi
  age=$(($(date +%s)-$(stat -c %Y "$log")))
  if [ "$age" -gt 720 ]; then
    echo "$(date -u +%FT%TZ) [$a] watchdog: log diam ${age}s -> restart" >>"$log"
    systemctl restart "$unit" 2>/dev/null
  fi
done
