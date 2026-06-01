#!/bin/bash
# Regenerate snapshot files (run periodically; commit when meaningful changes happen).
# Snapshots live in ./snapshots and are NOT stowed — they're restore inputs, not live configs.
#
# dconf dump is filtered to strip known secret keys and token-shaped values. After restore,
# reconfigure any extension that stored credentials (e.g. weekly-commits github-token) by hand.

set -eu

cd "$(dirname "$0")"
mkdir -p snapshots

DCONF_OUT="snapshots/gnome-dconf.ini"

# Keys whose entire line is dropped (case-insensitive match on key name before '=').
# Add new entries here when you discover another extension/app storing secrets in dconf.
SECRET_KEYS_REGEX='^(github[-_]?token|gitlab[-_]?token|api[-_]?key|api[-_]?token|access[-_]?token|auth[-_]?token|secret[-_]?key|client[-_]?secret|password|passphrase|bearer[-_]?token|private[-_]?key|openai[-_]?api[-_]?key|anthropic[-_]?api[-_]?key)='

# Token-shaped values get their value redacted to 'REDACTED' (keeps the key visible).
# Patterns: GitHub PATs (classic + fine-grained + app tokens), Slack, OpenAI, AWS, generic JWT/UUID-ish high entropy.
TOKEN_VALUE_PATTERNS="(github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{30,}|ghs_[A-Za-z0-9]{30,}|gho_[A-Za-z0-9]{30,}|ghu_[A-Za-z0-9]{30,}|ghr_[A-Za-z0-9]{30,}|xox[abprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_=-]+\\.[A-Za-z0-9_=-]+\\.[A-Za-z0-9_=-]+)"

echo "Dumping dconf /org/gnome/ -> $DCONF_OUT (filtering secrets)"
dconf dump /org/gnome/ | \
    sed -E "/${SECRET_KEYS_REGEX}/Id" | \
    sed -E "s/'${TOKEN_VALUE_PATTERNS}'/'REDACTED'/g" \
    > "$DCONF_OUT"

# Bail loudly if any token-shaped string survived.
if grep -E -q "${TOKEN_VALUE_PATTERNS}" "$DCONF_OUT"; then
    echo "ERROR: secret-shaped value remained in $DCONF_OUT after filtering." >&2
    echo "Inspect manually before committing:" >&2
    grep -nE "${TOKEN_VALUE_PATTERNS}" "$DCONF_OUT" >&2
    exit 1
fi

echo "Listing GNOME extensions -> snapshots/gnome-extensions.txt"
gnome-extensions list > snapshots/gnome-extensions.txt

echo "Listing explicit pacman packages -> snapshots/pkglist.txt"
pacman -Qqe > snapshots/pkglist.txt

echo "Listing AUR/foreign packages -> snapshots/aurlist.txt"
pacman -Qqm > snapshots/aurlist.txt

echo "Done."
