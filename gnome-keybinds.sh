#!/bin/bash
# Apply GNOME keybindings declaratively. Idempotent — safe to re-run.
#
# dconf is the live store, and `snapshot.sh` dumps it, but a dump records
# values, not intent. This file is the intent: it says which key does what and
# why, and it rebuilds the whole custom-keybinding list from scratch so stale
# orphan entries (dconf keeps custom<N>/ dirs that fall out of the index list)
# cannot accumulate.
#
# Run after `stow scripts` — several bindings point at ~/.local/bin.
set -euo pipefail

CK=org.gnome.settings-daemon.plugins.media-keys.custom-keybinding
CK_PATH=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings

# name | binding | command
# GNOME spawns these WITHOUT a shell (g_spawn_command_line_async), so no pipes,
# no $(...), no &&. Anything with logic goes in a script under ~/.local/bin.
CUSTOM=(
    "terminal|<Super>Return|ghostty"
    "terminal-alt|<Super>t|ghostty"
    "resources|<Shift><Control>Escape|resources"
    "ocr screenshot|<Super>Print|python3 $HOME/Projects/gnome-ocr/gnome-ocr-screenshot.py"
    "dnd|<Super>k|$HOME/.local/bin/dnd"
    "power profile|<Super><Shift>p|$HOME/.local/bin/toggle-power-profile"
)

# Clear every existing custom<N>/ dir, indexed or orphaned, then re-lay them.
for dir in $(dconf list "$CK_PATH/" 2>/dev/null || true); do
    dconf reset -f "$CK_PATH/$dir"
done

paths=()
for i in "${!CUSTOM[@]}"; do
    IFS='|' read -r name binding command <<< "${CUSTOM[$i]}"
    p="$CK_PATH/custom$i/"
    gsettings set "$CK:$p" name    "$name"
    gsettings set "$CK:$p" binding "$binding"
    gsettings set "$CK:$p" command "$command"
    paths+=("'$p'")
done
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "[$(IFS=,; echo "${paths[*]}")]"

# Super+1..9 raise the Nth dash-to-dock app. These ship enabled by default but
# were explicitly blanked, leaving nine prime accelerators dead.
for n in 1 2 3 4 5 6 7 8 9; do
    gsettings set org.gnome.shell.keybindings "switch-to-application-$n" "['<Super>$n']"
done

echo "Applied $(( ${#CUSTOM[@]} )) custom keybindings + Super+1..9 app switching."
