#!/bin/bash
# Shared config reader for Anchor hooks. Resolves repo root + config values.
anchor_root() {
  cd "${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}" 2>/dev/null \
    && pwd
}

# anchor_cfg <dotted.key> <fallback>  -> prints value (arrays as newline-joined)
anchor_cfg() {
  local key="$1" fallback="$2" root
  root="$(anchor_root)" || { printf '%s' "$fallback"; return; }
  local cfg="$root/anchor.config.json"
  [ -f "$cfg" ] || { printf '%s' "$fallback"; return; }
  python3 - "$cfg" "$key" "$fallback" <<'PY'
import json, sys
cfg, key, fallback = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(cfg))
except Exception:
    print(fallback); raise SystemExit
cur = data
for part in key.split("."):
    if isinstance(cur, dict) and part in cur:
        cur = cur[part]
    else:
        print(fallback); raise SystemExit
print("\n".join(map(str, cur)) if isinstance(cur, list) else cur)
PY
}
