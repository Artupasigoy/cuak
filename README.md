# cuak — penjaga sesi SSH human-like (~20KB, tanpa UI web)

Menahan sandbox/VPS agar tidak idle-sleep dengan sesi SSH persisten yang
bertingkah seperti manusia: ping bergantian (1.1.1.1/8.8.8.8) + jeda acak,
tercatat sebagai sesi `pts`.

## Install (3 baris, dependensi DIPAKSA install otomatis)

```bash
git clone https://github.com/Artupasigoy/cuak && cd cuak  # butuh: git
sudo bash install.sh
sudo cuak
```

## Menu (panah atas/bawah + Enter, `q`/Esc batal; non-TTY jadi angka)

`add device` (duplikat ditolak, koneksi dites dulu) · `status device` ·
`logs` · `remove` · `test` · `doctor` · `exit`

## 4 lapis ketangguhan per device

1. **autossh primer** (`GATETIME=0`, keepalive 60/3, `ConnectTimeout=15`, pty `-tt`)
2. **fallback ssh biasa** jika autossh hilang/gagal-cepat 3x
3. **retake otomatis** ke autossh (cooldown 10 mnt)
4. **systemd `Restart=on-failure` + watchdog 5 menitan** (restart holder zombie, trim log >5000 baris)

## Isolasi antar device (saling tidak mempengaruhi)

Unit, conf, key, known_hosts, log, lock masing-masing. `IdentitiesOnly`
(cuma key sendiri), tanpa ControlMaster sharing, monitor autossh `-M 0`.
Supervisi via PID + reap orphan bermarker key-path milik sendiri.

## Kompatibilitas

Linux + systemd. Client: OpenSSH >= 7.6, bash >= 4. Target: shell POSIX
(dash/ash didukung — loop remote tanpa bashism), `ping`/`date`/`sleep`
best-effort bila tak ada. Tanpa TTY, menu otomatis jadi angka.

## Uninstall

```bash
sudo bash uninstall.sh
```
