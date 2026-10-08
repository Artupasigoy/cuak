#!/bin/bash
# cuak-holder: supervisor 4 lapis per device.
# L1 autossh primer | L2 fallback ssh biasa | L3 retake otomatis | L4 systemd Restart + watchdog.
ALIAS="${1:?alias kosong}"
CONF="/etc/cuak/devices/$ALIAS.conf"
LOG="/var/log/cuak/$ALIAS.log"
[ -f "$CONF" ] || exit 1
# shellcheck disable=SC1090
. "$CONF"  # HOST PORT USER KEY PING1 PING2
exec 9>/run/cuak-holder-"$ALIAS".lock
flock -n 9 || exit 0  # anti double-start
log(){ echo "$(date -u +%FT%TZ) [$ALIAS] $*" >>"$LOG"; }
SSH_OPTS=(-tt -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=accept-new -p "${PORT:-22}" -i "$KEY")
REMOTE='while true;do ping -c2 -i1 -W2 '"${PING1:-1.1.1.1}"' >/dev/null 2>&1;echo "alive $(date -u +%FT%TZ)";sleep $((45+RANDOM%60));ping -c2 -i1 -W2 '"${PING2:-8.8.8.8}"' >/dev/null 2>&1;echo "cek $(date -u +%T)";sleep $((45+RANDOM%60));done'
backoff=15; fastfail=0; fallback_until=0
log "holder start (autossh primer)"
while true; do
  now=$(date +%s)
  T0=$now
  if command -v autossh >/dev/null 2>&1 && [ "$now" -ge "$fallback_until" ]; then
    MODE=autossh
    AUTOSSH_GATETIME=0 AUTOSSH_POLL=30 autossh -M 0 "${SSH_OPTS[@]}" "$USER@$HOST" "$REMOTE" 2>&1 | while IFS= read -r l; do echo "$(date -u +%FT%TZ) $l"; done >>"$LOG"
  else
    MODE=ssh-fallback
    log "pakai fallback ssh (autossh cooldown/missing)"
    ssh "${SSH_OPTS[@]}" "$USER@$HOST" "$REMOTE" 2>&1 | while IFS= read -r l; do echo "$(date -u +%FT%TZ) $l"; done >>"$LOG"
  fi
  DT=$(($(date +%s)-T0))
  if [ "$DT" -lt 20 ]; then fastfail=$((fastfail+1)); else fastfail=0; fi
  if [ "$fastfail" -ge 3 ]; then
    if [ "$MODE" = autossh ]; then fallback_until=$(($(date +%s)+600)); log "autossh gagal-cepat 3x -> fallback ssh 10 mnt (lalu retake otomatis)"; else log "ssh fallback juga gagal-cepat 3x -> jeda, coba lagi"; fi
    fastfail=0; backoff=120
  else
    log "sesi $MODE putus setelah ${DT}s -> sambung lagi ${backoff}s"
  fi
  sleep "$backoff"
  backoff=$((backoff<300 ? backoff*2 : 300))
  [ "$DT" -gt 300 ] && backoff=15
done
