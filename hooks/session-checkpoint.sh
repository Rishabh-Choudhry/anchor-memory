#!/bin/bash
# Stop + PreCompact: durable mechanical checkpoint so progress survives rate
# limits / abrupt close, and compaction is non-lossy. Advisory, never blocks.
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/_config.sh"
ROOT="$(anchor_root)" || exit 0
cd "$ROOT" || exit 0

STATE_DIR="$ROOT/.anchor"
mkdir -p "$STATE_DIR"
{
  echo "# Session state (auto-saved — last known reality)"
  echo
  printf "_Updated: %s_  ·  branch: \`%s\`\n\n" \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$(git symbolic-ref --short HEAD 2>/dev/null || echo n/a)"
  echo "## Uncommitted changes"
  status="$(git status --short 2>/dev/null)"
  if [ -n "$status" ]; then
    printf "\`\`\`\n%s\n\`\`\`\n\n" "$status"
    echo "Diff stat:"
    printf "\`\`\`\n%s\n\`\`\`\n" "$(git diff --stat 2>/dev/null | tail -20)"
  else
    echo "_(working tree clean)_"
  fi
  echo
  echo "## Recent commits"
  printf "\`\`\`\n%s\n\`\`\`\n" "$(git log --oneline -8 2>/dev/null || echo '(no history)')"
  echo
  echo "## Resume"
  echo "Read \`memory/HANDOFF.md\` for intent/next-step, then reconcile against the diff above. If HANDOFF.md is older than this checkpoint, trust the diff."
} > "$STATE_DIR/session-state.md"
exit 0
