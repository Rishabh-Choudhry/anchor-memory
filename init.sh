#!/bin/bash
# Anchor template bootstrap (non-plugin). Run from your project root after
# copying the anchor-memory template files in. Idempotent.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SRC="$(cd "$(dirname "$0")" && pwd)"
NAME="${1:-$(basename "$ROOT")}"
DATE="$(date +%Y-%m-%d)"

sub() {
  python3 - "$1" "$NAME" "$DATE" <<'PY'
import sys
src, name, date = sys.argv[1], sys.argv[2], sys.argv[3]
t = open(src, encoding="utf-8").read()
t = t.replace("{{PROJECT_NAME}}", name).replace("{{MEMORY_DIR}}", "memory")
t = t.replace("{{DATE}}", date).replace("{{BUILD_CMD}}", "# add your build command")
sys.stdout.write(t)
PY
}

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
write templates/memory/HANDOFF.md.tmpl memory/HANDOFF.md

# Vendor the engine + hooks for non-plugin use
mkdir -p "$ROOT/.anchor/hooks" "$ROOT/.anchor/scripts"
cp "$SRC"/hooks/*.sh "$ROOT/.anchor/hooks/"; chmod +x "$ROOT/.anchor/hooks/"*.sh
cp "$SRC"/scripts/memory_lint.py "$ROOT/.anchor/scripts/"
echo "Vendored hooks + linter into .anchor/"
# Auto-wire hooks for non-plugin (template) use: merge fragment into .claude/settings.json
python3 - "$SRC/templates/settings.fragment.json" "$ROOT/.claude/settings.json" <<'PY'
import json, os, sys
frag_path, settings_path = sys.argv[1], sys.argv[2]
frag = json.load(open(frag_path))
os.makedirs(os.path.dirname(settings_path), exist_ok=True)
settings = {}
if os.path.isfile(settings_path):
    try:
        settings = json.load(open(settings_path))
    except (json.JSONDecodeError, OSError):
        settings = {}
hooks = settings.setdefault("hooks", {})
for event, entries in frag.get("hooks", {}).items():
    existing = hooks.setdefault(event, [])
    for e in entries:
        if e not in existing:
            existing.append(e)
json.dump(settings, open(settings_path, "w"), indent=2)
print("wired hooks into .claude/settings.json")
PY
# Keep the auto-saved live state out of git (the vendored .anchor engine stays tracked)
GI="$ROOT/.gitignore"
if ! { [ -f "$GI" ] && grep -qxF ".anchor/session-state.md" "$GI"; }; then
  echo ".anchor/session-state.md" >> "$GI"
  echo "gitignored .anchor/session-state.md"
fi
python3 "$ROOT/.anchor/scripts/memory_lint.py" --root "$ROOT" || true
