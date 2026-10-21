#!/bin/bash
# Remove the cc-semaphore hook and clear its badges and tab colours.
set -euo pipefail

SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
IT2=/Applications/iTerm.app/Contents/Resources/utilities/it2
STATE_DIR="${TMPDIR:-/tmp}/cc-semaphore"

if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak-cc-iterm-semaphore"
  jq '
    def ours: (.command // "") | test("/cc-semaphore\"?$");
    if .hooks then
      .hooks |= with_entries(.value |= (map(.hooks |= map(select(ours | not))) | map(select(.hooks | length > 0))))
      | .hooks |= with_entries(select(.value | length > 0))
    else . end
  ' "$SETTINGS.bak-cc-iterm-semaphore" > "$SETTINGS.tmp"
  mv "$SETTINGS.tmp" "$SETTINGS"
fi

pkill -f cc-semaphore-watch 2>/dev/null || true

# Reset tab colour and badge in every session we touched
if [ -d "$STATE_DIR" ] && [ -x "$IT2" ]; then
  list=$("$IT2" session list 2>/dev/null || true)
  for f in "$STATE_DIR"/*; do
    [ -f "$f" ] || continue
    tty=$(grep -m1 "^${f##*/}" <<< "$list" | cut -f5 | tr -d '\\' || true)
    if [ -n "$tty" ] && [ -w "$tty" ]; then
      printf '\033]6;1;bg;*;default\a\033]1337;SetBadgeFormat=\a' > "$tty"
    fi
  done
fi
rm -rf "$STATE_DIR"

echo "Removed cc-semaphore from $SETTINGS (backup: $SETTINGS.bak-cc-iterm-semaphore)"
