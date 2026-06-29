# funinkina's dotfiles

Arch Linux + GNOME dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Stow packages

| Package      | Target                                              | App                                               |
| ------------ | --------------------------------------------------- | ------------------------------------------------- |
| `fish`       | `~/.config/fish/config.fish`                        | Fish shell                                        |
| `zsh`        | `~/.zshrc`                                          | Zsh                                               |
| `tmux`       | `~/.tmux.conf`                                      | Tmux                                              |
| `git`        | `~/.gitconfig`                                      | Git                                               |
| `ghostty`    | `~/.config/ghostty/config`                          | Ghostty terminal                                  |
| `starship`   | `~/.config/starship.toml`                           | Starship prompt                                   |
| `fastfetch`  | `~/.config/fastfetch/config.jsonc`                  | Fastfetch                                         |
| `zed`        | `~/.config/zed/settings.json`                       | Zed editor                                        |
| `fontconfig` | `~/.config/fontconfig/fonts.conf`                   | Fontconfig (Apple font aliases → Adwaita Sans)    |
| `color`      | `~/.local/share/color/icc/sRGB-v2-magic.icc`        | sRGB v2 ICC color profile                         |
| `gnome`      | `~/.config/monitors.xml`, `~/.config/mimeapps.list` | GNOME display layout + default apps               |
| `btop`       | `~/.config/btop/btop.conf` (+ themes/)              | btop system monitor                               |
| `electron`   | `~/.config/electron-flags.conf`                     | Electron app flags (Wayland etc.)                 |
| `scripts`    | `~/.local/bin/*`                                    | Custom user scripts (e.g. `toggle-power-profile`) |
| `wireplumber`| `~/.config/wireplumber/wireplumber.conf.d/50-ab13x-soft-volume.conf` | AB13X USB-C DAC: software volume (smooth low end, no cutoff) + device renames |

All packages installed:

```bash
stow --no-folding fish zsh tmux git ghostty starship fastfetch zed fontconfig color gnome btop electron scripts wireplumber
```

## Snapshots (not stowed)

`snapshots/` holds point-in-time exports that are **not** symlinked — they're inputs for restoring state on a fresh machine.

| File                             | Content                                                                            | Restore                                                          |
| -------------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `snapshots/gnome-dconf.ini`      | `dconf` dump of `/org/gnome/` (system + extensions + GNOME apps, secrets filtered) | `dconf load /org/gnome/ < snapshots/gnome-dconf.ini`             |
| `snapshots/gnome-extensions.txt` | Installed GNOME shell extensions                                                   | Reinstall via Extensions app / `gnome-extensions install`        |
| `snapshots/pkglist.txt`          | Explicitly installed pacman packages                                               | `sudo pacman -S --needed - < snapshots/pkglist.txt`              |
| `snapshots/aurlist.txt`          | AUR / foreign packages                                                             | Install via your AUR helper (`yay -S - < snapshots/aurlist.txt`) |

Regenerate snapshots: `./snapshot.sh`. Run before committing dotfiles changes.

## Not managed by stow

- `pacman.conf` — system file, copy manually to `/etc/pacman.conf` if needed.
- `backup.sh` — rsync-based external disk backup script. Edit `DEST_BASE_DIR` before use.

## Deliberately excluded

- `~/.config/gh/` — contains OAuth tokens. Use `gh auth login` after fresh install.
- `~/.ssh/`, `~/.gnupg/` — secrets. Back up out-of-band.
- `~/.icons/`, `~/.local/share/icons/` — icon themes (~40 MB). Reinstall via package manager.
- `~/.local/share/gnome-shell/extensions/` — tracked as list in `snapshots/gnome-extensions.txt`; reinstall, don't symlink.
- Browser profiles (`~/.mozilla`, `~/.config/google-chrome`) — use `backup.sh` rsync target instead.

## Setup on fresh machine

```bash
git clone <repo> ~/dotfiles
cd ~/dotfiles

# 1. Install packages
sudo pacman -S --needed - < snapshots/pkglist.txt
yay -S --needed - < snapshots/aurlist.txt   

# 2. Install stow + apply configs
sudo pacman -S stow
stow --no-folding fish zsh tmux git ghostty starship fastfetch zed fontconfig color gnome btop electron scripts wireplumber

# 3. Restore GNOME settings
dconf load /org/gnome/ < snapshots/gnome-dconf.ini

# 4. Reinstall GNOME extensions listed in snapshots/gnome-extensions.txt (via Extensions app)

# 5. (wireplumber pkg) pin the AB13X DAC hardware mixer at 0 dB for full
#    headroom under software volume, then persist it so reboot/replug keeps it:
amixer -c "$(cat /proc/asound/cards | awk '/AB13X/{print $1; exit}')" sset PCM 100%
sudo alsactl store
```

## Backing up changes

Stowed configs are symlinks — editing the live file (e.g. `~/.zshrc`) edits the repo file directly. To capture changes:

```bash
cd ~/dotfiles

# 1. Refresh snapshots (dconf dump, extension list, pkglist, aurlist).
./snapshot.sh

# 2. Review what changed.
git status
git diff

# 3. Stage + commit + push.
git add -A
git commit -m "update configs"
git push
```

Run `./snapshot.sh` whenever:

- You change a GNOME setting via Settings / Tweaks / an extension.
- You install or remove a package (`pacman -S`, `paru -S`, etc.).
- You install or remove a GNOME shell extension.

The script auto-filters known secret patterns (GitHub PATs, OpenAI keys, AWS keys, etc.) from the dconf dump and bails if a token-shaped value survives. If you add an extension that stores credentials under a new key name, extend `SECRET_KEYS_REGEX` in `snapshot.sh`.

## Adding a new app

1. Create a new top-level dir named after the app.
2. Mirror the target path relative to `$HOME` inside it. For `~/.config/foo/bar.conf` → `foo/.config/foo/bar.conf`.
3. `mv ~/.config/foo/bar.conf foo/.config/foo/bar.conf && stow --no-folding foo`.
