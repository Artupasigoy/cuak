#!/bin/bash
# cuak-holder: supervisor 4 lapis per device. ISOLASI PENUH antar device:
# conf/key/hosts/log/lock/unit masing-masing; IdentitiesOnly (cuma key sendiri);
# known_hosts per-device; Tanpa ControlMaster/multiplex sharing.
# L1 autossh primer | L2 fallback ssh | L3 retake otomatis | L4 systemd + watchdog.
# Anti-pipe-stuck: sesi diawasi via PID (kill -0/5 dtk), orphan di-reap via marker key-path.
ALIAS="${1:?alias kosong}"
CONF="/etc/cuak/devices/$ALIAS.conf"
LOG="/var/log/cuak/$ALIAS.log"
[ -f "$CONF" ] || exit 0
# shellcheck disable=SC1090
. "$CONF"  # HOST PORT USER KEY PING1 PING2
if [ -z "${HOST:-}" ] || ! [[ "${PORT:-22}" =~ ^[0-9]+$ ]] || [ -z "${USER:-}" ] || [ ! -f "${KEY:-}" ] || ! [[ "$HOST" =~ ^[A-Za-z0-9._:-]+$ ]] || ! [[ "$USER" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "$(date -u +%FT%TZ) [$ALIAS] conf rusak -> perbaiki via cuak remove+add" >>"$LOG"; exit 0
fi
exec 9>/run/cuak-holder-"$ALIAS".lock
flock -n 9 || exit 0  # anti double-start
log(){ echo "$(date -u +%FT%TZ) [$ALIAS] $*" >>"$LOG"; }
HOSTSFILE="${KEY}.hosts"
SSH_OPTS=(-tt -o BatchMode=yes -o IdentitiesOnly=yes -o UserKnownHostsFile="$HOSTSFILE" -o ConnectTimeout=15 -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=accept-new -p "${PORT:-22}" -i "$KEY")
REMOTE='while true;do ping -c2 -i1 -W2 '"${PING1:-1.1.1.1}"' >/dev/null 2>&1;echo "alive $(date -u +%FT%TZ)";sleep $((45+($(date +%S)%60)));ping -c2 -i1 -W2 '"${PING2:-8.8.8.8}"' >/dev/null 2>&1;echo "cek $(date -u +%T)";sleep $((45+($(date +%S)%60)));done'
reap(){ pkill -f -- "-i $KEY($| )" 2>/dev/null; sleep 2; }  # hanya milik device ini
run_supervised(){ # $@ = argv sesi; set DT (durasi). Tak peduli pipe dipegang orphan.
  local T0 pid
  T0=$(date +%s)
  "$@" > >(while IFS= read -r l; do echo "$(date -u +%FT%TZ) $l"; done >>"$LOG") 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do sleep 5; done
  wait "$pid" 2>/dev/null
  reap
  DT=$(($(date +%s)-T0))
}
backoff=15; fastfail=0; fallback_until=0
export AUTOSSH_GATETIME=0 AUTOSSH_POLL=30
log "holder start (autossh primer)"
while true; do
  now=$(date +%s)
  if command -v autossh >/dev/null 2>&1 && [ "$now" -ge "$fallback_until" ]; then
    MODE=autossh
    run_supervised autossh -M 0 "${SSH_OPTS[@]}" "$USER@$HOST" "$REMOTE"
  else
    MODE=ssh-fallback
    log "pakai fallback ssh (autossh cooldown/missing)"
    run_supervised ssh "${SSH_OPTS[@]}" "$USER@$HOST" "$REMOTE"
  fi
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
