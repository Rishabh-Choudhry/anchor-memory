#!/bin/bash
# Stop (ADVISORY — never blocks): nudge if watched code changed but memory didn't.
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/_config.sh"
ROOT="$(anchor_root)" || exit 0
cd "$ROOT" || exit 0

CHANGED="$(git status --porcelain 2>/dev/null)"
[ -z "$CHANGED" ] && exit 0

WATCH="$(anchor_cfg watch_globs $'src/\nlib/\napp/')"
LEDGER="$(anchor_cfg memory.ledger_files $'memory/decisions.md\nmemory/FACTS.md')"

code_changed=0; mem_changed=0
while IFS= read -r line; do
  path="${line:3}"
  while IFS= read -r g; do
    [ -z "$g" ] && continue
    pfx="${g%%\**}"
    case "$path" in "$pfx"*) code_changed=1 ;; esac
  done <<< "$WATCH"
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    [ "$path" = "$m" ] && mem_changed=1
  done <<< "$LEDGER"
done <<< "$CHANGED"

if [ "$code_changed" = "1" ] && [ "$mem_changed" = "0" ]; then
  echo "## 📝 Memory capture reminder (advisory)"
  echo "Watched code changed this session but the memory ledger did not."
  echo "If any decision was made or reversed, log it — and mark superseded entries 'status: superseded'."
fi
exit 0
