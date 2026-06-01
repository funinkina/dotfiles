# funinkina's dotfiles

Arch Linux + GNOME dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Stow packages

| Package      | Target                                              | App                                            |
| ------------ | --------------------------------------------------- | ---------------------------------------------- |
| `fish`       | `~/.config/fish/config.fish`                        | Fish shell                                     |
| `zsh`        | `~/.zshrc`                                          | Zsh                                            |
| `tmux`       | `~/.tmux.conf`                                      | Tmux                                           |
| `git`        | `~/.gitconfig`                                      | Git                                            |
| `ghostty`    | `~/.config/ghostty/config`                          | Ghostty terminal                               |
| `starship`   | `~/.config/starship.toml`                           | Starship prompt                                |
| `fastfetch`  | `~/.config/fastfetch/config.jsonc`                  | Fastfetch                                      |
| `zed`        | `~/.config/zed/settings.json`                       | Zed editor                                     |
| `fontconfig` | `~/.config/fontconfig/fonts.conf`                   | Fontconfig (Apple font aliases → Adwaita Sans) |
| `color`      | `~/.local/share/color/icc/sRGB-v2-magic.icc`        | sRGB v2 ICC color profile                      |
| `gnome`      | `~/.config/monitors.xml`, `~/.config/mimeapps.list` | GNOME display layout + default apps            |
| `btop`       | `~/.config/btop/btop.conf` (+ themes/)              | btop system monitor                            |
| `electron`   | `~/.config/electron-flags.conf`                     | Electron app flags (Wayland etc.)              |

All packages installed:

```bash
stow --no-folding fish zsh tmux git ghostty starship fastfetch zed fontconfig color gnome btop electron
```

## Snapshots (not stowed)

`snapshots/` holds point-in-time exports that are **not** symlinked — they're inputs for restoring state on a fresh machine.

| File                             | Content                                                             | Restore                                                          |
| -------------------------------- | ------------------------------------------------------------------- | ---------------------------------------------------------------- |
| `snapshots/gnome-dconf.ini`      | Full `dconf` dump (GNOME keybinds, extension prefs, theme settings) | `dconf load / < snapshots/gnome-dconf.ini`                       |
| `snapshots/gnome-extensions.txt` | Installed GNOME shell extensions                                    | Reinstall via Extensions app / `gnome-extensions install`        |
| `snapshots/pkglist.txt`          | Explicitly installed pacman packages                                | `sudo pacman -S --needed - < snapshots/pkglist.txt`              |
| `snapshots/aurlist.txt`          | AUR / foreign packages                                              | Install via your AUR helper (`yay -S - < snapshots/aurlist.txt`) |

Regenerate snapshots: `./snapshot.sh`. Run before committing dotfiles changes.

## Not managed by stow

- `pacman.conf` — system file, copy manually to `/etc/pacman.conf` if needed.
- `backup.sh` — rsync-based external disk backup script. Edit `DEST_BASE_DIR` before use.
- `sf-pro.zip` — SF Pro font archive.

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
stow --no-folding fish zsh tmux git ghostty starship fastfetch zed fontconfig color gnome btop electron

# 3. Restore GNOME settings
dconf load / < snapshots/gnome-dconf.ini

# 4. Reinstall GNOME extensions listed in snapshots/gnome-extensions.txt (via Extensions app)
```

## Adding a new app

1. Create a new top-level dir named after the app.
2. Mirror the target path relative to `$HOME` inside it. For `~/.config/foo/bar.conf` → `foo/.config/foo/bar.conf`.
3. `mv ~/.config/foo/bar.conf foo/.config/foo/bar.conf && stow --no-folding foo`.
