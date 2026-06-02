#!/bin/bash
# SessionStart: surface memory drift only when it exists (silent when clean).
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/_config.sh"
ROOT="$(anchor_root)" || exit 0
LINT="$DIR/../scripts/memory_lint.py"
[ -f "$LINT" ] || exit 0

OUT="$(python3 "$LINT" --quiet --root "$ROOT" 2>/dev/null)"
if [ -n "$OUT" ]; then
  echo "## ⚠️ MEMORY DRIFT — verify before trusting these entries"
  echo "$OUT"
  echo ""
  echo "These memory entries contradict the live repo or have broken/dangling links. Reconcile (update the entry or mark it superseded) before acting on them."
fi
exit 0
