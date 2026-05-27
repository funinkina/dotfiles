# funinkina's dotfiles

Arch Linux dotfiles.

## Includes

| File | App |
|------|-----|
| `config.fish` | Fish shell |
| `config.ghostty` | Ghostty terminal |
| `starship.toml` | Starship prompt |
| `.zshrc` | Zsh |
| `.tmux.conf` | Tmux |
| `.gitconfig` | Git |
| `config.jsonc` | Fastfetch |
| `settings.json` | Zed editor |
| `pacman.conf` | Pacman |
| `fonts.conf` | Fontconfig (Apple font aliases → Adwaita Sans) |
| `sRGB-v2-magic.icc` | sRGB v2 ICC color profile |
| `backup.sh` | External disk backup script |

## Setup

Clone and symlink configs to their expected locations. `backup.sh` uses rsync to back up specified directories to an external disk — edit `DEST_BASE_DIR` before use.
