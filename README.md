# cuak — penjaga sesi SSH human-like (~20KB, tanpa UI web)

Menahan sandbox/VPS agar tidak idle-sleep dengan sesi SSH persisten yang
bertingkah seperti manusia: ping bergantian (1.1.1.1/8.8.8.8) + jeda acak,
tercatat sebagai sesi `pts`.

## Install (3 baris, dependensi DIPAKSA install otomatis)

```bash
git clone https://github.com/<user>/cuak && cd cuak
sudo bash install.sh
sudo cuak
```

## Menu (navigasi panah atas/bawah + Enter, `q` batal)

`add device` (duplikat ditolak, koneksi dites dulu) · `status device` ·
`logs` · `remove` · `test` · `doctor` · `exit`.
Tanpa TTY (pipe/script) otomatis jadi menu angka 1-7.

## Isolasi antar device (saling tidak mempengaruhi)

Unit, conf, key, known_hosts, log, lock masing-masing. `IdentitiesOnly`
(cuma key sendiri, tanpa agent/default key lain), tanpa ControlMaster
sharing, monitor autossh `-M 0` (tanpa port). Supervisi via PID + reap
orphan bermarker key-path milik sendiri. Teruji: kill -9 autossh device A
-> A pulih sendiri, B tanpa satu baris `putus` pun; remove A -> B tetap jalan.

## 4 lapis ketangguhan per device

1. **autossh primer** (`GATETIME=0`, keepalive 60/3, `ConnectTimeout=15`, pty `-tt`)
2. **fallback ssh biasa** jika autossh hilang/gagal-cepat 3x
3. **retake otomatis** ke autossh (cooldown 10 mnt)
4. **systemd `Restart=always` + watchdog 5 menitan** (restart holder zombie)

## Uninstall

```bash
sudo bash uninstall.sh
```
