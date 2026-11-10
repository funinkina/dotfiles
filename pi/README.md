# Raspberry Pi 4 (4GB): always-on Hermes Agent

Headless, Ethernet, SD card root + USB flash drive for backups. The model runs in the cloud; the Pi only hosts the agent and its gateway (Telegram etc.).

## 1. Flash (on the Mac)

Raspberry Pi Imager → **Raspberry Pi OS Lite (64-bit)** → ⚙ settings: hostname `hermes`, user, **SSH public key**, timezone. Skip Wi-Fi. This erases the card.

Router: give the Pi a DHCP reservation so its IP never changes.

## 2. Harden (on the Pi)

```bash
scp -r ~/dotfiles/pi hermes:
ssh hermes
# Backup drive, once (ERASES it; check the device with lsblk first):
sudo mkfs.ext4 -L hermes-bak /dev/sda1
sudo ~/pi/setup.sh && sudo reboot
```

`setup.sh` (idempotent):

| Change | Why |
| --- | --- |
| journald → RAM | stops constant log writes to the SD |
| swap → RAM only (Trixie `rpi-swap` → `zram`; Bookworm `dphys-swapfile` off) | same |
| hardware watchdog (15s) | auto-reboots if the Pi hangs |
| `enable-linger` | Hermes user service starts at boot without a login |
| `LABEL=hermes-bak` → `/mnt/hermes-bak`, `nofail` | Pi still boots if the stick is missing or dead |
| `hermes-backup.timer`, 04:00 nightly, `Persistent` | runs on next boot if a power cut made it miss 04:00 |

Already Pi OS defaults, left alone: `noatime` on `/`, `fsck.repair=yes` in `cmdline.txt`.

## 3. Install Hermes

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc
hermes setup            # model + API key
hermes gateway setup    # say yes to the systemd user unit
```

Check it survives a reboot: `sudo reboot`, then `systemctl --user status` should show the gateway running.

If `hermes gateway status` warns "Gateway process is running … but the service is not active", `gateway setup` left a manual copy running. Kill that PID, then run `hermes gateway start`, so systemd restarts it on crash.

## 4. Web dashboard (LAN)

```bash
~/pi/dashboard-auth     # set the login first (12+ char password); the dashboard won't start on the LAN without one
mkdir -p ~/.config/systemd/user && cp ~/pi/hermes-dashboard.service ~/.config/systemd/user/
systemctl --user daemon-reload && systemctl --user enable --now hermes-dashboard
```

Open `http://<pi-ip>:9119` (DHCP-reserved IP; `.local` names don't resolve on this router). The username is your Pi user. The password is stored only as an scrypt hash, plus a fixed random session secret so logins survive restarts.

Limits: it's plain HTTP, so the password and session cookie cross the LAN unencrypted, and it only works at home. Never port-forward 9119; the dashboard holds your API keys.

**Later, from anywhere (Tailscale, HTTPS):** in `hermes-dashboard.service`, set `--host 127.0.0.1`, then:
```bash
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up && sudo tailscale set --operator=$USER
tailscale serve --bg 9119 && tailscale serve status       # gives https://<pi-name>.<tailnet>.ts.net
~/pi/dashboard-auth https://<pi-name>.<tailnet>.ts.net    # behind a proxy the Host must match public_url
```

## Backups

`hermes-backup` makes a hardlinked daily snapshot of `~/.hermes` in `/mnt/hermes-bak/YYYY-MM-DD` and keeps the last 14 (`latest` points to the newest). SQLite DBs, found by file header rather than extension, are copied with `sqlite3 .backup`, so each copy is consistent even while Hermes is writing to it. It skips code, runtimes and caches (`hermes-agent`, `tools`, `installs`, `*cache`, about 2.9 GB that the installer recreates), so a snapshot is around 12 MB.

After editing `hermes-backup`, reinstall it: `sudo install -m755 ~/pi/hermes-backup /usr/local/bin/`.

```bash
hermes-backup                                   # run now
systemctl list-timers hermes-backup.timer       # next run
journalctl -u hermes-backup                     # last result (RAM log, cleared by reboot)
```

**Restore** (new SD card after a failure): repeat steps 1–3 but **skip the `mkfs` line**, because it would erase your backups. The install recreates the excluded code. Then stop the gateway, run
`rsync -a /mnt/hermes-bak/latest/ ~/.hermes/` (no `--delete`, so the freshly installed code stays), and start it again.

New or reformatted stick: it starts out owned by root, so backups fail with "not writable". Rerun `sudo ~/pi/setup.sh` and it will fix the ownership.

## Limits

- The SD card itself is the weak point. Power cuts can still corrupt a cheap card's controller. Next upgrades, in order: a high-endurance card, booting from a USB SSD, a UPS HAT.
- The backup lives on a drive plugged into the same Pi, so it covers card death, not theft, fire or a power surge. For an off-device copy, also rsync it to the Mac.
