#!/bin/bash
# Anchor template bootstrap (non-plugin). Run from your project root after
# copying the anchor-memory template files in. Idempotent.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SRC="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:-$(basename "$ROOT")}"
DATE="$(date +%Y-%m-%d)"

sub() { sed -e "s/{{PROJECT_NAME}}/$NAME/g" -e "s/{{MEMORY_DIR}}/memory/g" \
            -e "s/{{DATE}}/$DATE/g" -e "s/{{BUILD_CMD}}/# add your build command/g" "$1"; }

write() { # write <template> <dest>
  if [ -e "$ROOT/$2" ]; then echo "skip (exists): $2"; else
    mkdir -p "$ROOT/$(dirname "$2")"; sub "$SRC/$1" > "$ROOT/$2"; echo "wrote: $2"; fi
}

write templates/AGENTS.md.tmpl AGENTS.md
write templates/CLAUDE.md.tmpl CLAUDE.md
write templates/GEMINI.md.tmpl GEMINI.md
write templates/anchor.config.json.tmpl anchor.config.json
write templates/memory/FACTS.md.tmpl memory/FACTS.md
write templates/memory/decisions.md.tmpl memory/decisions.md
write templates/memory/status.md.tmpl memory/status.md
write templates/memory/README.md memory/README.md

# Vendor the engine + hooks for non-plugin use
mkdir -p "$ROOT/.anchor/hooks" "$ROOT/.anchor/scripts"
cp "$SRC"/hooks/*.sh "$ROOT/.anchor/hooks/"; chmod +x "$ROOT/.anchor/hooks/"*.sh
cp "$SRC"/scripts/memory_lint.py "$ROOT/.anchor/scripts/"
echo "Vendored hooks + linter into .anchor/"
echo "Next: merge templates/settings.fragment.json into .claude/settings.json"
python3 "$ROOT/.anchor/scripts/memory_lint.py" --root "$ROOT" || true
