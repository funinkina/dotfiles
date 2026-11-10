#!/usr/bin/env bash
# Harden Raspberry Pi OS Lite (64-bit) for an always-on Hermes Agent.
# Run on the Pi from this directory: sudo ./setup.sh   (idempotent)
set -euo pipefail
[[ $EUID -eq 0 && -n ${SUDO_USER:-} ]] || { echo "run as: sudo $0" >&2; exit 1; }
user=$SUDO_USER
cd "$(dirname "$0")"
export DEBIAN_FRONTEND=noninteractive

apt=(apt-get -y -o DPkg::Lock::Timeout=600)  # first boot: apt-daily may hold the lock
"${apt[@]}" update
"${apt[@]}" full-upgrade
"${apt[@]}" install git curl xz-utils sqlite3 rsync

# Logs in RAM: no constant SD writes. Lost on reboot, by design.
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=volatile\nRuntimeMaxUse=64M\n' > /etc/systemd/journald.conf.d/volatile.conf

# No swap on the SD card. Trixie (rpi-swap): zram only, no writeback file.
if [[ -f /etc/rpi/swap.conf ]]; then
  mkdir -p /etc/rpi/swap.conf.d
  printf '[Main]\nMechanism=zram\n' > /etc/rpi/swap.conf.d/90-zram-only.conf
fi
# Bookworm (dphys-swapfile).
if command -v dphys-swapfile >/dev/null; then
  dphys-swapfile swapoff || true
  dphys-swapfile uninstall || true
  systemctl disable --now dphys-swapfile
fi

# Hardware watchdog: auto-reboot if the kernel hangs. 15s is the bcm2835 max.
cfg=/boot/firmware/config.txt
grep -q '^dtparam=watchdog=on' "$cfg" || echo 'dtparam=watchdog=on' >> "$cfg"
mkdir -p /etc/systemd/system.conf.d
printf '[Manager]\nRuntimeWatchdogSec=15\n' > /etc/systemd/system.conf.d/watchdog.conf

# Hermes gateway runs as a systemd *user* unit; linger starts it at boot without a login.
loginctl enable-linger "$user"

# Backup flash drive: ext4 labelled hermes-bak. nofail = boots fine without it.
mkdir -p /mnt/hermes-bak
grep -q 'LABEL=hermes-bak' /etc/fstab ||
  echo 'LABEL=hermes-bak /mnt/hermes-bak ext4 defaults,noatime,nofail,x-systemd.device-timeout=5s 0 2' >> /etc/fstab
systemctl daemon-reload
if mountpoint -q /mnt/hermes-bak || mount /mnt/hermes-bak 2>/dev/null; then
  chown "$user:" /mnt/hermes-bak
else
  echo "note: backup drive not mounted (see README)"
fi

install -m755 hermes-backup /usr/local/bin/hermes-backup
cat > /etc/systemd/system/hermes-backup.service <<EOF
[Unit]
Description=Snapshot ~/.hermes to the backup drive
RequiresMountsFor=/mnt/hermes-bak

[Service]
Type=oneshot
User=$user
ExecStart=/usr/local/bin/hermes-backup
EOF
cat > /etc/systemd/system/hermes-backup.timer <<'EOF'
[Unit]
Description=Nightly ~/.hermes snapshot

[Timer]
OnCalendar=*-*-* 04:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now hermes-backup.timer

echo "done. reboot now: sudo reboot"
