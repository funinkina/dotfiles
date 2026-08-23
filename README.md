# funinkina's dotfiles

Arch Linux + GNOME dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

The `niri`, `quickshell`, `walker` and `elephant` packages are a **second, currently
inactive desktop** — none of those four are installed right now, and the live session is
GNOME Shell. They are stowed and kept warm, not in use. See "Inactive desktop" below.

## Stow packages

| Package      | Target                                              | App                                               |
| ------------ | --------------------------------------------------- | ------------------------------------------------- |
| `fish`       | `~/.config/fish/config.fish`                        | Fish shell                                        |
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
| `applications`| `~/.local/share/applications/*.desktop`            | Extra launcher entries (Helium per-profile: Aryan / Libra AI) |
| `satty`      | `~/.config/satty/{config.toml,overrides.css}`       | Satty screenshot annotation (theme + palette from Theme.qml) |
| `wireplumber`| `~/.config/wireplumber/wireplumber.conf.d/` | `00-plasma-pa.conf` (device renames) + `50-ab13x-soft-volume.conf` (AB13X USB-C DAC: software volume, smooth low end / no cutoff) |
| `claude`     | `~/.claude/{CLAUDE.md,settings.json,statusline.sh,skills/}` | Claude Code — global instructions, settings, status line, custom skills |
| `kitty`      | `~/.config/kitty/kitty.conf`                         | Kitty terminal — **not installed**; `ghostty` is the live terminal |
| `vscode`     | `~/.vscode/argv.json`                                | VS Code launch args                                 |

All packages installed:

```bash
stow --no-folding fish tmux git kitty ghostty starship fastfetch zed vscode fontconfig color gnome btop electron scripts wireplumber applications satty claude niri quickshell walker elephant
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

## Keybindings (`gnome-keybinds.sh`)

`dconf` is where GNOME keeps shortcuts, and `snapshot.sh` dumps it — but a dump records
values, not intent. `gnome-keybinds.sh` is the intent: one table saying which key runs
what. It is idempotent, and it rebuilds the custom-keybinding list from scratch each run
so orphaned `custom<N>/` entries can't pile up in dconf.

```bash
stow --no-folding scripts   # several bindings point at ~/.local/bin
./gnome-keybinds.sh
```

GNOME spawns custom-keybinding commands through `g_spawn_command_line_async` — **there is
no shell**. Pipes, `&&`, and `$(...)` are passed through as literal argv and silently do
nothing. Anything with logic belongs in a script under `scripts/.local/bin/` (see `dnd`).

| Key | Action |
| --- | --- |
| `Super+Return` / `Super+T` | Ghostty |
| `Super+K` | Do Not Disturb (`dnd`) |
| `Super+Shift+P` | Cycle power profile (`toggle-power-profile`) |
| `Super+Print` | OCR screenshot |
| `Ctrl+Shift+Escape` | Resources (system monitor) |
| `Super+1`…`9` | Raise Nth dash-to-dock app |

## Not managed by stow

- `pacman.conf` — system file, copy manually to `/etc/pacman.conf` if needed.
- `sddm-theme/noir/` — SDDM login theme. Install with `sudo cp -r sddm-theme/noir /usr/share/sddm/themes/` and set `Current=noir` in `/etc/sddm.conf`.
- `backup.sh` — rsync-based external disk backup script. Edit `DEST_BASE_DIR` before use.

## Inactive desktop (niri + quickshell)

`niri/`, `quickshell/`, `walker/` and `elephant/` describe a scrolling-WM desktop that is
**not currently installed or running**. The configs are stowed, so editing them is live
the moment the stack is installed, but nothing reads them today.

`snapshots/pkglist.txt` does not contain any of it — the snapshot predates the experiment.
Reviving the stack means installing `niri quickshell walker elephant swaybg satty swayidle
brightnessctl` by hand first; the pkglist will not do it for you.

## Deliberately excluded

- `~/.config/gh/` — contains OAuth tokens. Use `gh auth login` after fresh install.
- `~/.ssh/`, `~/.gnupg/` — secrets. Back up out-of-band.
- `~/.icons/`, `~/.local/share/icons/` — icon themes (~40 MB). Reinstall via package manager.
- `~/.local/share/gnome-shell/extensions/` — tracked as list in `snapshots/gnome-extensions.txt`; reinstall, don't symlink.
- Browser profiles (`~/.mozilla`, `~/.config/google-chrome`) — use `backup.sh` rsync target instead.
- Most of `~/.claude/` — the `claude` package deliberately stows config only (~9 files). Everything else there is secrets, account state, or regenerable bulk (~660 MB):
  - `.credentials.json` — OAuth tokens. Re-run `claude` and log in.
  - `.claude.json` — machine ID, account UUIDs, per-project history. Machine-specific, regenerates.
  - `projects/`, `file-history/`, `history.jsonl`, `sessions/` — transcripts and edit history. This is the bulk of the 660 MB.
  - `plugins/` — reinstalled from marketplaces per `settings.json` `enabledPlugins`.
  - `skills/humanizer/` — upstream clone, not our work. Restore with
    `git clone https://github.com/blader/humanizer.git ~/.claude/skills/humanizer`.
  - caches (`cache/`, `paste-cache/`, `image-cache/`, `session-env/`, `shell-snapshots/`, `jobs/`) — all regenerable.

  `.gitignore` enforces this as an allowlist (`claude/.claude/*` plus `!` exceptions), so dropping a stray file into the package won't silently commit it.

## Setup on fresh machine

```bash
git clone <repo> ~/dotfiles
cd ~/dotfiles

# 1. Install packages
sudo pacman -S --needed - < snapshots/pkglist.txt
yay -S --needed - < snapshots/aurlist.txt   

# 2. Install stow + apply configs
sudo pacman -S stow
stow --no-folding fish tmux git kitty ghostty starship fastfetch zed vscode fontconfig color gnome btop electron scripts wireplumber applications satty claude niri quickshell walker elephant

# 3. Restore GNOME settings
dconf load /org/gnome/ < snapshots/gnome-dconf.ini

# 4. Reinstall GNOME extensions listed in snapshots/gnome-extensions.txt (via Extensions app)

# 5. (wireplumber pkg) pin the AB13X DAC hardware mixer at 0 dB for full
#    headroom under software volume, then persist it so reboot/replug keeps it:
amixer -c "$(cat /proc/asound/cards | awk '/AB13X/{print $1; exit}')" sset PCM 100%
sudo alsactl store
```

## Backing up changes

Stowed configs are symlinks — editing the live file (e.g. `~/.tmux.conf`) edits the repo file directly. To capture changes:

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
