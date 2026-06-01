# funinkina's dotfiles

Arch Linux dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Packages

| Package | Target | App |
|---------|--------|-----|
| `fish` | `~/.config/fish/config.fish` | Fish shell |
| `zsh` | `~/.zshrc` | Zsh |
| `tmux` | `~/.tmux.conf` | Tmux |
| `git` | `~/.gitconfig` | Git |
| `ghostty` | `~/.config/ghostty/config` | Ghostty terminal |
| `starship` | `~/.config/starship.toml` | Starship prompt |
| `fastfetch` | `~/.config/fastfetch/config.jsonc` | Fastfetch |
| `zed` | `~/.config/zed/settings.json` | Zed editor |
| `fontconfig` | `~/.config/fontconfig/fonts.conf` | Fontconfig (Apple font aliases → Adwaita Sans) |
| `color` | `~/.local/share/color/icc/sRGB-v2-magic.icc` | sRGB v2 ICC color profile |

Not managed by stow:

- `pacman.conf` — system file, copy manually to `/etc/pacman.conf` if needed.
- `backup.sh` — rsync-based external disk backup script. Edit `DEST_BASE_DIR` before use.
- `sf-pro.zip` — SF Pro font archive.

## Setup

```bash
git clone <repo> ~/dotfiles
cd ~/dotfiles
stow --no-folding fish zsh tmux git ghostty starship fastfetch zed fontconfig color
```

`--no-folding` makes stow symlink individual files instead of whole directories, so apps that write other files into `~/.config/<app>/` (e.g. Zed keymap, fastfetch state) don't end up in the repo.

To stow a single package: `stow --no-folding fish`. To unstow: `stow -D fish`.

## Adding a new app

1. Create a new top-level dir named after the app.
2. Inside it, mirror the target path relative to `$HOME`. For `~/.config/foo/bar.conf` → `foo/.config/foo/bar.conf`.
3. `stow --no-folding foo`.
