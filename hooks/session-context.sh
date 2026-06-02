#!/bin/bash
# SessionStart: surface recent git activity + current project status.
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/_config.sh"
ROOT="$(anchor_root)" || exit 0
cd "$ROOT" || exit 0

echo "## Recent Changes"
git log --oneline -10 2>/dev/null || echo "(no git history)"
echo ""
echo "## Working Tree"
git status --short 2>/dev/null | head -15
echo ""

MEM_DIR="$(anchor_cfg memory.dir memory)"
if [ -f "$ROOT/$MEM_DIR/status.md" ]; then
  echo "## Current Status"
  sed -n '/^---$/,/^---$/!p' "$ROOT/$MEM_DIR/status.md" | head -30
fi

if [ -f "$ROOT/memory/HANDOFF.md" ]; then
  echo ""
  echo "## Handoff — intent / next step (memory/HANDOFF.md)"
  head -40 "$ROOT/memory/HANDOFF.md"
fi
if [ -f "$ROOT/.anchor/session-state.md" ]; then
  echo ""
  echo "## Last auto-saved state (.anchor/session-state.md)"
  head -40 "$ROOT/.anchor/session-state.md"
fi
exit 0
