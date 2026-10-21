#!/bin/bash
# Register cc-semaphore as a Claude Code hook (safe to re-run).
set -euo pipefail

cd "$(dirname "$0")"
HOOK="$PWD/bin/cc-semaphore"
SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
IT2=/Applications/iTerm.app/Contents/Resources/utilities/it2
EVENTS='["SessionStart","UserPromptSubmit","PreToolUse","PostToolUse","PostToolUseFailure",
         "PermissionRequest","Notification","Elicitation","ElicitationResult",
         "Stop","StopFailure","SessionEnd"]'

command -v jq >/dev/null || { echo "jq is required: brew install jq" >&2; exit 1; }
[ -x "$IT2" ] || echo "warning: $IT2 not found — iTerm2 3.7+ is needed for the watcher" >&2

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-cc-iterm-semaphore"

# Drop earlier cc-semaphore registrations (from any path), then add ours to every event
jq --arg cmd "\"$HOOK\"" --argjson events "$EVENTS" '
  def ours: (.command // "") | test("/cc-semaphore\"?$");
  .hooks //= {}
  | .hooks |= with_entries(.value |= (map(.hooks |= map(select(ours | not))) | map(select(.hooks | length > 0))))
  | .hooks |= with_entries(select(.value | length > 0))
  | reduce $events[] as $e (.; .hooks[$e] += [{hooks: [{type: "command", command: $cmd, timeout: 5}]}])
' "$SETTINGS.bak-cc-iterm-semaphore" > "$SETTINGS.tmp"
mv "$SETTINGS.tmp" "$SETTINGS"

# A watcher started from an older copy would keep running the old code
pkill -f cc-semaphore-watch 2>/dev/null || true

echo "Installed: $HOOK"
echo "Settings:  $SETTINGS (backup: $SETTINGS.bak-cc-iterm-semaphore)"
echo "Running Claude Code sessions pick it up on their next event."
