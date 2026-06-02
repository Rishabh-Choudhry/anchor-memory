# Anchor (anchor-memory) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `anchor-memory` — a public, MIT-licensed, multi-agent Claude Code plugin (brand "Anchor") that ships verifiable-memory machinery (linter + 3 hooks + `@meta` anchor convention) and a `memory-init` skill that scaffolds the in-repo memory ledger + CLAUDE.md/AGENTS.md/GEMINI.md into any project.

**Architecture:** Plugin-first, scaffold-as-output. The repo is simultaneously (a) a Claude Code marketplace+plugin with per-agent manifests over a shared `skills/` + `hooks/`, and (b) a GitHub template. Everything project-specific is driven by a single `anchor.config.json` so the linter and hooks are path-independent. `memory-init` (and an equivalent `init.sh`) writes the repo-resident files and wires `.claude/settings.json`.

**Tech Stack:** Bash (hooks, init.sh), Python 3.9+ stdlib only (linter + tests via `unittest`), Markdown (templates, skills, docs), JSON (plugin manifests + config), GitHub Actions (CI).

**Build location:** New directory `/Users/rishabhc/workspaces/anchor-memory` (a fresh git repo, independent of `workout_mvp`). All paths below are relative to that repo root unless absolute.

**Source assets to port (from `workout_mvp`):**
- `scripts/audit/memory_lint.py` → `scripts/memory_lint.py`
- `scripts/audit/test_memory_lint.py` → `tests/test_memory_lint.py`
- `.claude/hooks/{session-context,memory-integrity-scan,memory-integrity-gate}.sh` → `hooks/`

---

## File Structure

```
anchor-memory/
├── README.md                         # social landing page
├── LICENSE                           # MIT (Anchor)
├── CREDITS.md                        # karpathy-skills MIT attribution
├── CHANGELOG.md
├── anchor.config.schema.json         # JSON Schema for the per-project config
├── .claude-plugin/{marketplace.json, plugin.json}
├── .codex-plugin/plugin.json
├── .cursor-plugin/plugin.json
├── .opencode/plugins/anchor.json
├── hooks/
│   ├── session-context.sh
│   ├── memory-integrity-scan.sh
│   ├── memory-integrity-gate.sh
│   ├── _config.sh                    # shared config-reader helper
│   └── hooks.json
├── scripts/
│   └── memory_lint.py                # config-aware, stdlib only
├── tests/
│   └── test_memory_lint.py
├── skills/
│   ├── memory-init/SKILL.md
│   ├── capture-decision/SKILL.md
│   ├── update-status/SKILL.md
│   ├── recall/SKILL.md
│   ├── session-wrapup/SKILL.md
│   └── review-pr/SKILL.md
├── templates/
│   ├── AGENTS.md.tmpl
│   ├── CLAUDE.md.tmpl
│   ├── GEMINI.md.tmpl
│   ├── anchor.config.json.tmpl
│   ├── settings.fragment.json
│   ├── memory/{FACTS.md.tmpl, decisions.md.tmpl, status.md.tmpl, README.md}
│   └── auto-memory/{MEMORY.md.tmpl, fact-file.md.tmpl}
├── init.sh                           # GitHub-template scaffold path
├── docs/{philosophy.md, anchor-anchors-spec.md, tool-mappings.md}
└── .github/{workflows/ci.yml, ISSUE_TEMPLATE/bug_report.md, ISSUE_TEMPLATE/feature_request.md}
```

---

## Milestone M0 — Skeleton & config contract

### Task 1: Initialize repo and base files

**Files:**
- Create: `/Users/rishabhc/workspaces/anchor-memory/.gitignore`
- Create: `/Users/rishabhc/workspaces/anchor-memory/LICENSE`
- Create: `/Users/rishabhc/workspaces/anchor-memory/README.md` (stub; finalized in Task 19)
- Create: `/Users/rishabhc/workspaces/anchor-memory/CHANGELOG.md`

- [ ] **Step 1: Create the directory and init git**

```bash
mkdir -p /Users/rishabhc/workspaces/anchor-memory
cd /Users/rishabhc/workspaces/anchor-memory
git init -b main
mkdir -p .claude-plugin .codex-plugin .cursor-plugin .opencode/plugins \
  hooks scripts tests skills templates/memory templates/auto-memory \
  docs .github/workflows .github/ISSUE_TEMPLATE
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
.DS_Store
__pycache__/
*.pyc
.anchor-tmp/
node_modules/
```

- [ ] **Step 3: Write `LICENSE`** — standard MIT, copyright line `Copyright (c) 2026 Rishabh Choudhry`.

- [ ] **Step 4: Write `README.md` stub**

```markdown
# Anchor

> The memory system for coding agents that catches itself lying.

Verifiable, self-policing project memory for Claude Code, Codex, Cursor, and Gemini.
Full README lands in Task 19.
```

- [ ] **Step 5: Write `CHANGELOG.md`**

```markdown
# Changelog

## [Unreleased]
- Initial scaffold.
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "chore: initialize anchor-memory repo skeleton"
```

### Task 2: Define the config contract (`anchor.config.json`)

This is the seam that de-hardcodes the linter and hooks. Define the schema once; everything reads it.

**Files:**
- Create: `anchor.config.schema.json`
- Create: `docs/anchor-anchors-spec.md` (the `@meta` anchor convention reference)

- [ ] **Step 1: Write `anchor.config.schema.json`**

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "title": "Anchor project config",
  "type": "object",
  "required": ["memory"],
  "properties": {
    "project_name": { "type": "string" },
    "memory": {
      "type": "object",
      "required": ["dir", "ledger_files"],
      "properties": {
        "dir": { "type": "string", "default": "memory" },
        "ledger_files": {
          "type": "array",
          "items": { "type": "string" },
          "default": ["memory/decisions.md", "memory/FACTS.md"]
        },
        "auto_memory_dir": { "type": "string" }
      }
    },
    "watch_globs": {
      "type": "array",
      "description": "Code paths whose changes should trigger the memory-capture nudge.",
      "items": { "type": "string" },
      "default": ["src/**", "lib/**", "app/**"]
    },
    "review": {
      "type": "object",
      "properties": {
        "license_allowlist": { "type": "array", "items": { "type": "string" } },
        "invariants": { "type": "array", "items": { "type": "string" } }
      }
    }
  }
}
```

- [ ] **Step 2: Write `docs/anchor-anchors-spec.md`** documenting the convention (full content):

````markdown
# Anchor `@meta` anchor spec

A memory entry may carry a machine-checkable `@meta` block. The linter
(`scripts/memory_lint.py`) evaluates each anchor against the live repo and
flags entries that have drifted.

## Block syntax

```
<!-- @meta
id: unique-kebab-id
status: active            # active | superseded | retracted
supersedes: older-id      # optional
anchors:
  - kind: file_exists
    file: path/to/file
    expect: present        # present | absent
  - kind: file_grep
    file: path/to/file
    pattern: "some string"
    expect: present        # present | absent | count:N
    scope_after: "## Heading"   # optional: only search after this marker
  - kind: json_field
    file: path/to/file.json
    field: some_key
    expect: ">= 0.9"       # supports >= <= == > < or exact string
  - kind: golden_metric
    file: path/to/table.csv
    column: passed
    match_value: "True"
    expect: "count >= 10"
-->
```

## Finding kinds
- `DRIFT` — anchor evaluated but reality disagrees (entry is stale).
- `BROKEN` — anchor can't be evaluated (missing file/field/marker).
- `DANGLING` — `supersedes` points at an unknown id.
- `DUPLICATE` — same `id` used by more than one entry.

Entries with `status: superseded|retracted` are skipped during anchor eval.
````

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: config schema + @meta anchor spec"
```

---

## Milestone M1 — Portable engine (linter + hooks)

### Task 3: Port and generalize the linter

The only project-specific code is the hardcoded `DEFAULT_FILES`. Generalize it to read `anchor.config.json` when present.

**Files:**
- Create: `scripts/memory_lint.py` (copy of source, with the change below)
- Test: `tests/test_memory_lint.py` (Task 4)

- [ ] **Step 1: Copy the source linter verbatim**

```bash
cp /Users/rishabhc/workspaces/workout_mvp/scripts/audit/memory_lint.py \
   /Users/rishabhc/workspaces/anchor-memory/scripts/memory_lint.py
```

- [ ] **Step 2: Replace the `DEFAULT_FILES` constant + add a config loader**

Replace the line `DEFAULT_FILES = ["memory/decisions.md", "memory/FACTS.md"]` with:

```python
DEFAULT_FILES = ["memory/decisions.md", "memory/FACTS.md"]


def _files_from_config(root: str) -> list[str] | None:
    """Read ledger file list from anchor.config.json if present."""
    cfg_path = os.path.join(root, "anchor.config.json")
    if not os.path.isfile(cfg_path):
        return None
    try:
        with open(cfg_path, encoding="utf-8") as f:
            cfg = json.load(f)
        files = cfg.get("memory", {}).get("ledger_files")
        return files or None
    except (json.JSONDecodeError, OSError):
        return None
```

- [ ] **Step 3: Use the loader in `main()`**

Replace `files = args.files if args.files is not None else DEFAULT_FILES` with:

```python
    if args.files is not None:
        files = args.files
    else:
        files = _files_from_config(args.root) or DEFAULT_FILES
```

- [ ] **Step 4: Update the module docstring** (line 3) to point at the new spec:

```python
stdlib only (no pyyaml/pytest). See docs/anchor-anchors-spec.md
```

- [ ] **Step 5: Commit**

```bash
git add scripts/memory_lint.py
git commit -m "feat(lint): config-aware ledger file resolution"
```

### Task 4: Port linter tests + add a config-resolution test

**Files:**
- Create: `tests/test_memory_lint.py`

- [ ] **Step 1: Copy the source tests and fix the import path**

```bash
cp /Users/rishabhc/workspaces/workout_mvp/scripts/audit/test_memory_lint.py \
   /Users/rishabhc/workspaces/anchor-memory/tests/test_memory_lint.py
```

Then ensure the import resolves from `scripts/`. At the top of the test file, the import must be:

```python
import os
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import memory_lint  # noqa: E402
```

- [ ] **Step 2: Add a new failing test for config-driven file resolution**

Append to `tests/test_memory_lint.py`:

```python
import json
import tempfile
import unittest


class ConfigResolutionTest(unittest.TestCase):
    def test_reads_ledger_files_from_config(self):
        with tempfile.TemporaryDirectory() as root:
            with open(os.path.join(root, "anchor.config.json"), "w") as f:
                json.dump({"memory": {"dir": "mem",
                                      "ledger_files": ["mem/facts.md"]}}, f)
            self.assertEqual(memory_lint._files_from_config(root), ["mem/facts.md"])

    def test_missing_config_returns_none(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertIsNone(memory_lint._files_from_config(root))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run the tests, expect PASS**

Run: `cd /Users/rishabhc/workspaces/anchor-memory && python3 -m unittest discover -s tests -v`
Expected: all tests PASS (ported tests + the 2 new config tests).

- [ ] **Step 4: Commit**

```bash
git add tests/test_memory_lint.py
git commit -m "test(lint): port tests + config resolution coverage"
```

### Task 5: De-hardcode the three hooks

Hooks must read paths from `anchor.config.json` via a shared helper, with safe fallbacks. No absolute paths, no project-specific globs.

**Files:**
- Create: `hooks/_config.sh`
- Create: `hooks/session-context.sh`
- Create: `hooks/memory-integrity-scan.sh`
- Create: `hooks/memory-integrity-gate.sh`

- [ ] **Step 1: Write `hooks/_config.sh`** (shared reader; pure POSIX + python3 for JSON)

```bash
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
```

- [ ] **Step 2: Write `hooks/session-context.sh`** (de-hardcoded `MEMORY_DIR`)

```bash
#!/bin/bash
# SessionStart: surface recent git activity + current project status.
DIR="$(cd "$(dirname "$0")" && pwd)"
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
exit 0
```

- [ ] **Step 3: Write `hooks/memory-integrity-scan.sh`** (de-hardcoded; finds the linter relative to the plugin)

```bash
#!/bin/bash
# SessionStart: surface memory drift only when it exists (silent when clean).
DIR="$(cd "$(dirname "$0")" && pwd)"
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
```

- [ ] **Step 4: Write `hooks/memory-integrity-gate.sh`** (config-driven watch-globs + ledger paths)

```bash
#!/bin/bash
# Stop (ADVISORY — never blocks): nudge if watched code changed but memory didn't.
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_config.sh"
ROOT="$(anchor_root)" || exit 0
cd "$ROOT" || exit 0

CHANGED="$(git status --porcelain 2>/dev/null)"
[ -z "$CHANGED" ] && exit 0

# Build a grep alternation from watch_globs (glob '**' -> regex). Fallback covers common roots.
WATCH="$(anchor_cfg watch_globs $'src/\nlib/\napp/')"
LEDGER="$(anchor_cfg memory.ledger_files $'memory/decisions.md\nmemory/FACTS.md')"

code_changed=0; mem_changed=0
while IFS= read -r line; do
  path="${line:3}"
  while IFS= read -r g; do
    [ -z "$g" ] && continue
    pfx="${g%%\**}"   # strip glob tail -> directory prefix
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
```

- [ ] **Step 5: Make hooks executable + shellcheck**

Run:
```bash
chmod +x hooks/*.sh
shellcheck hooks/*.sh || echo "shellcheck not installed — install before CI"
```
Expected: no errors (warnings about `_config.sh` sourcing are acceptable; suppress with `# shellcheck source=/dev/null` above each `. "$DIR/_config.sh"` line if flagged).

- [ ] **Step 6: Manual smoke test in a scratch repo**

Run:
```bash
tmp="$(mktemp -d)"; cd "$tmp"; git init -q
printf '{"memory":{"dir":"memory","ledger_files":["memory/FACTS.md"]}}' > anchor.config.json
mkdir memory; printf '# FACTS\n' > memory/FACTS.md
CLAUDE_PROJECT_DIR="$tmp" bash /Users/rishabhc/workspaces/anchor-memory/hooks/session-context.sh
cd - >/dev/null
```
Expected: prints "## Recent Changes" / "## Working Tree" sections without error; no absolute-path leakage.

- [ ] **Step 7: Commit**

```bash
cd /Users/rishabhc/workspaces/anchor-memory
git add hooks/
git commit -m "feat(hooks): config-driven, path-independent session + integrity hooks"
```

### Task 6: Hook wiring manifest (`hooks/hooks.json`)

**Files:**
- Create: `hooks/hooks.json`

- [ ] **Step 1: Write `hooks/hooks.json`** (referenced by the plugin manifest and copied by `memory-init`)

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [
        { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-context.sh" },
        { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/memory-integrity-scan.sh" }
      ] }
    ],
    "Stop": [
      { "hooks": [
        { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/memory-integrity-gate.sh" }
      ] }
    ]
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add hooks/hooks.json && git commit -m "feat(hooks): SessionStart + Stop wiring manifest"
```

---

## Milestone M2 — Templates (scaffold output)

### Task 7: Instruction templates (AGENTS.md canonical, CLAUDE/GEMINI pointers)

**Files:**
- Create: `templates/AGENTS.md.tmpl`
- Create: `templates/CLAUDE.md.tmpl`
- Create: `templates/GEMINI.md.tmpl`
- Create: `CREDITS.md`

- [ ] **Step 1: Write `templates/AGENTS.md.tmpl`** (single source of truth; opens with attributed karpathy section)

````markdown
# {{PROJECT_NAME}} — Agent Instructions

> Behavioral guidelines below adapted from
> [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) (MIT).
> See CREDITS.md.

## How to work

**1. Think before coding.** State assumptions; if multiple interpretations exist, present them — don't pick silently. If unclear, stop and ask.

**2. Simplicity first.** Minimum code that solves the problem. No speculative features, abstractions, or config that wasn't requested.

**3. Surgical changes.** Touch only what you must. Match existing style. Don't refactor what isn't broken. Remove only the orphans your change created.

**4. Goal-driven execution.** Turn each task into a verifiable success criterion, then loop until it's met.

## Source of truth (read first every session)

- `{{MEMORY_DIR}}/FACTS.md` — current facts + the **tried-and-failed list**. Read before proposing any new approach.
- `{{MEMORY_DIR}}/decisions.md` — load-bearing decisions. **Check before "fixing" something that looks wrong.**
- `{{MEMORY_DIR}}/status.md` — what's done / blocked / next.

## Build & run

```bash
{{BUILD_CMD}}
```

## Project structure

<!-- Describe top-level dirs and their one-line responsibility. -->

## Key decisions (DO NOT change without discussion)

<!-- Load-bearing constraints. Each links to a decisions.md entry. -->

## Memory ritual (MANDATORY at end of session)

1. Update `decisions.md` if any load-bearing decision was made/changed (date + WHY + impact).
2. Update `status.md` if phase progress changed.
3. Mark superseded entries `status: superseded` — don't delete history.

## Compaction instructions

Preserve: FACTS.md in full, the source-of-truth pointers, Key decisions, current task context, and any file paths/line numbers in the active task. Drop: verbose tool output, intermediate search results, already-committed diffs.
````

- [ ] **Step 2: Write `templates/CLAUDE.md.tmpl`** (thin pointer carrying the behavioral section)

```markdown
# CLAUDE.md

This project's agent instructions live in **[AGENTS.md](./AGENTS.md)** — the single
source of truth. Read it first. The behavioral guidelines and memory ritual there
apply to Claude Code.

For Claude-specific tool names vs other agents, see `docs/tool-mappings.md`
(installed with the Anchor plugin).
```

- [ ] **Step 3: Write `templates/GEMINI.md.tmpl`**

```markdown
# GEMINI.md

Project instructions live in **[AGENTS.md](./AGENTS.md)** — read it first.
Gemini tool-name equivalents: see `docs/tool-mappings.md`.
```

- [ ] **Step 4: Write `CREDITS.md`**

```markdown
# Credits

Anchor's behavioral "How to work" guidelines (in the AGENTS.md/CLAUDE.md templates)
are adapted from **andrej-karpathy-skills** by forrestchang, used under the MIT License.

Source: https://github.com/forrestchang/andrej-karpathy-skills

Original copyright notice retained per MIT terms:

> MIT License — Copyright (c) andrej-karpathy-skills contributors
```

- [ ] **Step 5: Commit**

```bash
git add templates/AGENTS.md.tmpl templates/CLAUDE.md.tmpl templates/GEMINI.md.tmpl CREDITS.md
git commit -m "feat(templates): multi-agent instruction templates + karpathy attribution"
```

### Task 8: Memory ledger templates

**Files:**
- Create: `templates/memory/FACTS.md.tmpl`
- Create: `templates/memory/decisions.md.tmpl`
- Create: `templates/memory/status.md.tmpl`
- Create: `templates/memory/README.md`

- [ ] **Step 1: Write `templates/memory/FACTS.md.tmpl`**

````markdown
# FACTS — mandatory read before any plan, experiment, or recommendation

**Purpose:** single-page source of truth for current facts + what's been tried.
Prevents re-proposing already-failed approaches and re-quoting stale numbers.

**Rule:** Read this FIRST every session. Before proposing any new approach, confirm
it is not on the "Tried & failed" list below.

**Last verified:** {{DATE}}

---

## Current facts

<!-- Stable, load-bearing facts. Attach @meta anchors so the linter can verify them. -->

<!-- @meta
id: example-fact
status: active
anchors:
  - kind: file_exists
    file: README.md
    expect: present
-->

| Fact | Source | Verified |
|------|--------|----------|
| _example_ | `README.md` | {{DATE}} |

## Tried & failed (anti-repetition firewall)

<!-- Every measured-and-rejected approach. Never re-propose without new evidence. -->

| Approach | Why it failed | When |
|----------|---------------|------|
| _none yet_ | | |
````

- [ ] **Step 2: Write `templates/memory/decisions.md.tmpl`**

```markdown
# Decisions

Load-bearing decisions only. Each: date, WHY, impact. **Check before "fixing"
something that looks wrong — it may be intentional.**

---

## {{DATE}} — Adopted Anchor memory discipline
**Why:** keep agent memory verifiable and prevent re-litigating settled choices.
**Impact:** memory ledger + @meta anchors + integrity hooks are now in effect.
**Status:** active
```

- [ ] **Step 3: Write `templates/memory/status.md.tmpl`**

```markdown
# Status

## Now
- [ ] _current focus_

## Next
- [ ] _queued_

## Blocked
- [ ] _waiting on_

## Done
- [x] Initialized Anchor memory ledger ({{DATE}})
```

- [ ] **Step 4: Write `templates/memory/README.md`**

```markdown
# memory/

The project's git-tracked ledger (source of truth).

- **FACTS.md** — read first; current facts + tried-and-failed firewall.
- **decisions.md** — load-bearing decisions (why + impact).
- **status.md** — done / next / blocked.

Entries can carry `@meta` anchors (see `docs/anchor-anchors-spec.md`) so
`memory_lint.py` flags any entry that drifts from the live repo.
```

- [ ] **Step 5: Commit**

```bash
git add templates/memory/
git commit -m "feat(templates): memory ledger skeletons (FACTS/decisions/status)"
```

### Task 9: Auto-memory templates + tool mappings + philosophy

**Files:**
- Create: `templates/auto-memory/MEMORY.md.tmpl`
- Create: `templates/auto-memory/fact-file.md.tmpl`
- Create: `docs/tool-mappings.md`
- Create: `docs/philosophy.md`

- [ ] **Step 1: Write `templates/auto-memory/MEMORY.md.tmpl`**

```markdown
# {{PROJECT_NAME}} — Memory Index

One line per memory file. No content here — just pointers.

## User
<!-- - [Title](file.md) — hook -->

## Feedback
<!-- - [Title](file.md) — hook -->

## Project
<!-- - [Title](file.md) — hook -->

## Reference
<!-- - [Title](file.md) — hook -->
```

- [ ] **Step 2: Write `templates/auto-memory/fact-file.md.tmpl`**

```markdown
---
name: <short-kebab-slug>
description: <one-line summary used for recall relevance>
metadata:
  type: user | feedback | project | reference
---

<the fact. For feedback/project, add **Why:** and **How to apply:** lines.
Link related memories with [[their-name]].>
```

- [ ] **Step 3: Write `docs/tool-mappings.md`**

```markdown
# Tool-name equivalents across agents

| Concept | Claude Code | Codex | Cursor | Gemini CLI |
|---------|-------------|-------|--------|------------|
| Read file | Read | read_file | read | read_file |
| Edit file | Edit | apply_patch | edit | edit |
| Search text | Grep | grep/ripgrep | grep | search |
| Run shell | Bash | shell | terminal | run_shell_command |
| List dir | Glob/LS | list | list | list_directory |

AGENTS.md is the shared instruction file; this table lets one set of
instructions read naturally regardless of the agent's native tool names.
```

- [ ] **Step 4: Write `docs/philosophy.md`** (the "why")

```markdown
# Why Anchor

Coding agents forget, and worse, they confidently repeat settled mistakes and
quote facts that are no longer true. Anchor fixes this with three moves:

1. **A ledger, not a chat log.** FACTS / decisions / status are the durable
   source of truth, read first every session.
2. **Memory you can falsify.** Entries carry `@meta` anchors checked against the
   live repo. If reality moved, the entry is flagged as drifted.
3. **A closed loop.** Hooks surface drift at session start and nudge capture at
   session end, so the ledger stays honest without discipline-by-willpower.

The machinery is a plugin (install once, updates centrally). The ledger is
repo-resident (it's your project's memory). `memory-init` connects the two.
```

- [ ] **Step 5: Commit**

```bash
git add templates/auto-memory/ docs/tool-mappings.md docs/philosophy.md
git commit -m "feat(templates,docs): auto-memory templates, tool mappings, philosophy"
```

### Task 10: Config + settings templates

**Files:**
- Create: `templates/anchor.config.json.tmpl`
- Create: `templates/settings.fragment.json`

- [ ] **Step 1: Write `templates/anchor.config.json.tmpl`**

```json
{
  "project_name": "{{PROJECT_NAME}}",
  "memory": {
    "dir": "memory",
    "ledger_files": ["memory/decisions.md", "memory/FACTS.md"],
    "auto_memory_dir": ""
  },
  "watch_globs": ["src/**", "lib/**", "app/**"],
  "review": { "license_allowlist": [], "invariants": [] }
}
```

- [ ] **Step 2: Write `templates/settings.fragment.json`** (the block `memory-init`/`init.sh` merge into `.claude/settings.json`)

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.anchor/hooks/session-context.sh" },
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.anchor/hooks/memory-integrity-scan.sh" }
      ] }
    ],
    "Stop": [
      { "hooks": [
        { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.anchor/hooks/memory-integrity-gate.sh" }
      ] }
    ]
  }
}
```

> Note: the GitHub-template path (Task 12) vendors hooks into `.anchor/hooks/`. The plugin path uses `${CLAUDE_PLUGIN_ROOT}` (Task 6) and does NOT need this fragment — `memory-init` only writes this fragment when run in template (non-plugin) mode.

- [ ] **Step 3: Commit**

```bash
git add templates/anchor.config.json.tmpl templates/settings.fragment.json
git commit -m "feat(templates): project config + settings hook fragment"
```

---

## Milestone M3 — Keystone: `memory-init` + `init.sh`

### Task 11: `memory-init` skill

**Files:**
- Create: `skills/memory-init/SKILL.md`

- [ ] **Step 1: Write `skills/memory-init/SKILL.md`** (full content)

````markdown
---
name: memory-init
description: Use to bootstrap Anchor in a project — scaffolds AGENTS.md/CLAUDE.md/GEMINI.md, the memory ledger, anchor.config.json, and wires the integrity hooks. Idempotent.
---

# memory-init

Scaffold the Anchor memory system into the current project. Safe to re-run
(never overwrites an existing file without showing a diff and asking).

## Steps

1. **Detect context.** Confirm you are at the repo root (`git rev-parse --show-toplevel`).
   Detect if Anchor is installed as a plugin (`$CLAUDE_PLUGIN_ROOT` set) or being
   used template-style (files copied into the repo).

2. **Interview (minimal).** Ask only:
   - Project name (default: repo directory name).
   - Primary build/test command (default: leave the `{{BUILD_CMD}}` placeholder).
   Everything else uses defaults and is editable later in `anchor.config.json`.

3. **Resolve template source.** Templates live at `${CLAUDE_PLUGIN_ROOT}/templates`
   (plugin mode) or `./templates` (template mode). Abort with a clear message if
   neither exists.

4. **Write files** (skip+report any that already exist; offer to diff/overwrite):
   - `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` ← templates, with `{{PROJECT_NAME}}`,
     `{{MEMORY_DIR}}`, `{{BUILD_CMD}}`, `{{DATE}}` substituted.
   - `memory/FACTS.md`, `memory/decisions.md`, `memory/status.md`, `memory/README.md`.
   - `anchor.config.json` ← template with substitutions.

5. **Wire hooks.**
   - Plugin mode: hooks are already active via the plugin's `hooks/hooks.json`.
     Tell the user no settings change is needed.
   - Template mode: copy `templates/../hooks/` into `.anchor/hooks/`, copy
     `scripts/memory_lint.py` into `.anchor/scripts/`, then merge
     `templates/settings.fragment.json` into `.claude/settings.json`
     (create the file if absent; merge arrays, don't clobber existing hooks).

6. **Verify.** Run `python3 <linter> --root . ` and report the result. Then print a
   3-line "what changed + next steps" summary (edit AGENTS.md project sections;
   record your first decision with /capture-decision).

## Guardrails
- Never delete existing memory. Never overwrite without explicit confirmation.
- All substitutions are literal string replacements of the `{{...}}` tokens.
````

- [ ] **Step 2: Commit**

```bash
git add skills/memory-init/SKILL.md
git commit -m "feat(skill): memory-init keystone scaffold skill"
```

### Task 12: `init.sh` (GitHub-template scaffold path)

Implements the same scaffold as `memory-init` step 4–5 for non-plugin users, deterministically.

**Files:**
- Create: `init.sh`

- [ ] **Step 1: Write `init.sh`**

```bash
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
```

- [ ] **Step 2: Make executable + smoke test in a scratch repo**

Run:
```bash
chmod +x /Users/rishabhc/workspaces/anchor-memory/init.sh
tmp="$(mktemp -d)"; (cd "$tmp" && git init -q && \
  /Users/rishabhc/workspaces/anchor-memory/init.sh demo && \
  test -f AGENTS.md && test -f memory/FACTS.md && test -d .anchor/hooks && \
  grep -q "demo" AGENTS.md && echo "INIT OK")
```
Expected: prints `wrote:` lines then `INIT OK`. No `{{` tokens remain in `AGENTS.md`.

- [ ] **Step 3: Commit**

```bash
cd /Users/rishabhc/workspaces/anchor-memory
git add init.sh
git commit -m "feat: init.sh template-mode scaffold (parity with memory-init)"
```

### Task 13: End-to-end dogfood

- [ ] **Step 1: Full scaffold + drift demo in a throwaway repo**

Run:
```bash
tmp="$(mktemp -d)"; cd "$tmp"; git init -q
/Users/rishabhc/workspaces/anchor-memory/init.sh dogfood
# Add a verifiable anchor that will pass, then break it:
python3 .anchor/scripts/memory_lint.py --root .   # expect: all MATCH ✓ (example-fact anchors README.md which is absent -> create it)
printf '# readme\n' > README.md
python3 .anchor/scripts/memory_lint.py --root .   # expect: clean
# Break it: point example anchor at a missing file by removing README
rm README.md
python3 .anchor/scripts/memory_lint.py --root . || echo "DRIFT DETECTED (expected)"
cd - >/dev/null
```
Expected: linter reports DRIFT/BROKEN for the `example-fact` entry when `README.md` is missing, proving the loop works. (Fix the FACTS.md template example anchor if the example doesn't behave as documented.)

- [ ] **Step 2: No commit** (verification only). Note any fixes made and commit them under the relevant task.

---

## Milestone M4 — Workflow skills

### Task 14: `capture-decision`, `update-status`, `recall`, `session-wrapup`

**Files:**
- Create: `skills/capture-decision/SKILL.md`
- Create: `skills/update-status/SKILL.md`
- Create: `skills/recall/SKILL.md`
- Create: `skills/session-wrapup/SKILL.md`

- [ ] **Step 1: Write `skills/capture-decision/SKILL.md`**

````markdown
---
name: capture-decision
description: Use when a load-bearing decision was made or reversed — appends a dated, WHY-first entry to the memory ledger, optionally with a verifiable @meta anchor.
---

# capture-decision

1. Read `memory/decisions.md`.
2. Append an entry: `## {DATE} — {short title}` then `**Why:** … **Impact:** … **Status:** active`.
3. If the decision is tied to a file/metric, add an `@meta` block (see
   `docs/anchor-anchors-spec.md`) so the linter can verify it later.
4. If this reverses a prior decision, set the old entry's `status: superseded`
   and add `supersedes: <old-id>` to the new one.
5. Run `python3 <linter> --root .` to confirm no new drift was introduced.
````

- [ ] **Step 2: Write `skills/update-status/SKILL.md`**

````markdown
---
name: update-status
description: Use to move items between Now/Next/Blocked/Done in the project status ledger.
---

# update-status

1. Read `memory/status.md`.
2. Move the relevant item to the correct section; check off completed items.
3. Keep it short — status is a snapshot, not a log. Detailed rationale belongs
   in `decisions.md`.
````

- [ ] **Step 3: Write `skills/recall/SKILL.md`**

````markdown
---
name: recall
description: Use before proposing any new architecture, experiment, or comparison — reads the ledger and runs the integrity linter so you don't re-propose a failed idea or quote stale facts.
---

# recall

1. Read `memory/FACTS.md` in full — especially the **Tried & failed** list.
2. Read relevant `memory/decisions.md` entries.
3. Run `python3 <linter> --quiet --root .`. If it prints anything, those entries
   have drifted — reconcile them before trusting them.
4. Only then propose. If your proposal matches a "Tried & failed" row, stop and
   surface that unless you have new evidence.
````

- [ ] **Step 4: Write `skills/session-wrapup/SKILL.md`**

````markdown
---
name: session-wrapup
description: Use at the end of a work session to run the memory ritual — capture decisions, update status, mark superseded entries.
---

# session-wrapup

1. Did any load-bearing decision get made/reversed? → use `capture-decision`.
2. Did phase progress change? → use `update-status`.
3. Any entry now false? → mark `status: superseded` (don't delete history).
4. Run `python3 <linter> --root .`; resolve any DRIFT/BROKEN before ending.
````

- [ ] **Step 5: Commit**

```bash
git add skills/capture-decision skills/update-status skills/recall skills/session-wrapup
git commit -m "feat(skills): capture-decision, update-status, recall, session-wrapup"
```

### Task 15: Generalized `review-pr` skill

**Files:**
- Create: `skills/review-pr/SKILL.md`

- [ ] **Step 1: Write `skills/review-pr/SKILL.md`** (checklist sourced from `anchor.config.json`, not hardcoded)

````markdown
---
name: review-pr
description: Use to review a pull request against the project's own rules — license allowlist and architecture invariants read from anchor.config.json.
argument-hint: [pr-number-or-url]
---

# review-pr

1. Fetch the PR: `gh pr view {{arguments}} --json title,files` and
   `gh pr diff {{arguments}}`.
2. Load `anchor.config.json` → `review.license_allowlist` and `review.invariants`.
3. Check the diff against:
   - **Licenses:** any new dependency must be on `license_allowlist` (if the list
     is non-empty). Flag anything outside it as a blocker.
   - **Invariants:** each string in `review.invariants` is a rule the diff must not
     violate. Flag violations as blockers.
   - **Memory:** if the diff changes watched code but not the ledger, remind the
     author to record decisions.
4. Output: `### Blockers`, `### Suggestions`, `### Looks good`. License/invariant
   violations are hard blockers.
````

- [ ] **Step 2: Commit**

```bash
git add skills/review-pr/SKILL.md
git commit -m "feat(skill): config-driven review-pr"
```

---

## Milestone M5 — Packaging (multi-agent plugin)

### Task 16: Claude marketplace + plugin manifests

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `.claude-plugin/plugin.json`

- [ ] **Step 1: Write `.claude-plugin/marketplace.json`** (repo-as-marketplace)

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "anchor-memory",
  "id": "anchor-memory",
  "owner": { "name": "Rishabh Choudhry" },
  "metadata": {
    "description": "Anchor — verifiable, self-policing memory for coding agents.",
    "version": "0.1.0"
  },
  "plugins": [
    {
      "name": "anchor-memory",
      "source": "./",
      "description": "Verifiable agent memory: ledger + @meta anchors + integrity hooks + scaffold skill.",
      "version": "0.1.0",
      "author": { "name": "Rishabh Choudhry" },
      "keywords": ["agent memory", "claude code", "codex", "cursor", "gemini",
                   "ai agent context", "llm memory", "hooks", "skills"],
      "category": "workflow"
    }
  ]
}
```

- [ ] **Step 2: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "anchor-memory",
  "description": "Anchor: verifiable, self-policing project memory for coding agents — ledger + @meta anchors + integrity hooks + memory-init scaffold.",
  "version": "0.1.0",
  "author": { "name": "Rishabh Choudhry" },
  "homepage": "https://github.com/Rishabh-Choudhry/anchor-memory",
  "repository": "https://github.com/Rishabh-Choudhry/anchor-memory",
  "license": "MIT",
  "keywords": ["agent memory", "claude code", "codex", "cursor", "gemini",
               "ai agent context", "llm memory", "hooks", "skills"],
  "skills": "./skills/",
  "hooks": "./hooks/hooks.json"
}
```

- [ ] **Step 3: Validate JSON**

Run: `python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('.claude-plugin/*.json')]; print('JSON OK')"`
Expected: `JSON OK`

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/
git commit -m "feat(plugin): Claude marketplace + plugin manifests"
```

### Task 17: Multi-agent manifests (Codex, Cursor, opencode)

**Files:**
- Create: `.codex-plugin/plugin.json`
- Create: `.cursor-plugin/plugin.json`
- Create: `.opencode/plugins/anchor.json`

- [ ] **Step 1: Write `.codex-plugin/plugin.json`**

```json
{
  "name": "anchor-memory",
  "version": "0.1.0",
  "description": "Verifiable, self-policing project memory for coding agents.",
  "author": { "name": "Rishabh Choudhry" },
  "homepage": "https://github.com/Rishabh-Choudhry/anchor-memory",
  "repository": "https://github.com/Rishabh-Choudhry/anchor-memory",
  "license": "MIT",
  "keywords": ["agent memory", "codex", "claude code", "cursor", "gemini", "llm memory"],
  "skills": "./skills/",
  "interface": {
    "displayName": "Anchor",
    "shortDescription": "Verifiable agent memory: ledger + anchors + integrity hooks.",
    "category": "Coding"
  }
}
```

- [ ] **Step 2: Write `.cursor-plugin/plugin.json`** (same shape, `"keywords"` lead with `cursor`)

```json
{
  "name": "anchor-memory",
  "version": "0.1.0",
  "description": "Verifiable, self-policing project memory for coding agents.",
  "author": { "name": "Rishabh Choudhry" },
  "homepage": "https://github.com/Rishabh-Choudhry/anchor-memory",
  "repository": "https://github.com/Rishabh-Choudhry/anchor-memory",
  "license": "MIT",
  "keywords": ["agent memory", "cursor", "claude code", "codex", "gemini", "llm memory"],
  "skills": "./skills/"
}
```

- [ ] **Step 3: Write `.opencode/plugins/anchor.json`**

```json
{
  "name": "anchor-memory",
  "version": "0.1.0",
  "description": "Verifiable, self-policing project memory for coding agents.",
  "license": "MIT",
  "skills": "../../skills/"
}
```

- [ ] **Step 4: Validate all manifests**

Run: `python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('.*-plugin/*.json')+glob.glob('.opencode/plugins/*.json')]; print('ALL JSON OK')"`
Expected: `ALL JSON OK`

- [ ] **Step 5: Commit**

```bash
git add .codex-plugin .cursor-plugin .opencode
git commit -m "feat(plugin): multi-agent manifests (codex, cursor, opencode)"
```

### Task 18: Local install verification

- [ ] **Step 1: Add the local repo as a marketplace in Claude Code and install**

Run (in Claude Code, via the user — suggest the `!`-prefixed commands or the slash UI):
```
/plugin marketplace add /Users/rishabhc/workspaces/anchor-memory
/plugin install anchor-memory
```
Expected: plugin installs; `/memory-init`, `/recall`, `/capture-decision`, `/update-status`, `/session-wrapup`, `/review-pr` appear in the skill list; SessionStart shows the session-context digest.

- [ ] **Step 2: Run `/memory-init` in a scratch project and confirm files scaffold + hooks fire.** Note any fixes; commit them under the owning task.

---

## Milestone M6 — Launch polish

### Task 19: README landing page

**Files:**
- Modify: `README.md` (replace the Task 1 stub)

- [ ] **Step 1: Write the full `README.md`**

````markdown
# Anchor 🪢

> The memory system for coding agents that catches itself lying.

Anchor gives Claude Code / Codex / Cursor / Gemini a **verifiable, self-policing
project ledger**. Facts and decisions carry machine-checkable `@meta` anchors; a
linter + hooks flag any entry that has drifted from the live repo — *before* the
agent trusts it. Stop your agent re-proposing failed ideas and quoting stale facts.

## Install (Claude Code — recommended)

```
/plugin marketplace add Rishabh-Choudhry/anchor-memory
/plugin install anchor-memory
```

Then, in any project:

```
/memory-init
```

That scaffolds `AGENTS.md` + `CLAUDE.md` + `GEMINI.md`, seeds the `memory/`
ledger, and wires the integrity hooks. Done in under a minute.

## Install (other agents / no plugin)

"Use this template" on GitHub (or copy the repo), then:

```bash
./init.sh "My Project"
```

## What you get

- **Ledger** — `FACTS.md` (current facts + a tried-and-failed firewall),
  `decisions.md`, `status.md`. Read first, every session.
- **Verifiable memory** — `@meta` anchors checked against the repo (`file_exists`,
  `file_grep`, `json_field`, `golden_metric`).
- **Closed-loop hooks** — drift surfaced at session start; capture nudged at end.
- **Skills** — `memory-init`, `recall`, `capture-decision`, `update-status`,
  `session-wrapup`, `review-pr`.

## How it works

See [docs/philosophy.md](docs/philosophy.md) and the anchor spec in
[docs/anchor-anchors-spec.md](docs/anchor-anchors-spec.md).

## Acknowledgements

Behavioral "How to work" guidelines adapted from
[andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills)
(MIT). See [CREDITS.md](CREDITS.md).

## License

MIT.
````

- [ ] **Step 2: Commit**

```bash
git add README.md && git commit -m "docs: README landing page"
```

### Task 20: CI + issue templates

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/ISSUE_TEMPLATE/bug_report.md`
- Create: `.github/ISSUE_TEMPLATE/feature_request.md`

- [ ] **Step 1: Write `.github/workflows/ci.yml`**

```yaml
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.11" }
      - name: Lint tests
        run: python3 -m unittest discover -s tests -v
      - name: Validate plugin JSON
        run: python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('.*-plugin/*.json')+glob.glob('.opencode/plugins/*.json')+['.claude-plugin/marketplace.json']]; print('JSON OK')"
      - name: Shellcheck hooks
        run: sudo apt-get update && sudo apt-get install -y shellcheck && shellcheck hooks/*.sh init.sh
```

- [ ] **Step 2: Write `.github/ISSUE_TEMPLATE/bug_report.md`**

```markdown
---
name: Bug report
about: Something in Anchor isn't working
labels: bug
---

**What happened**
**Expected**
**Agent + version** (Claude Code / Codex / Cursor / Gemini)
**Repro steps**
```

- [ ] **Step 3: Write `.github/ISSUE_TEMPLATE/feature_request.md`**

```markdown
---
name: Feature request
about: Suggest an improvement
labels: enhancement
---

**Problem**
**Proposed solution**
**Alternatives considered**
```

- [ ] **Step 4: Run CI steps locally to confirm green**

Run:
```bash
cd /Users/rishabhc/workspaces/anchor-memory
python3 -m unittest discover -s tests -v
python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('.*-plugin/*.json')+glob.glob('.opencode/plugins/*.json')]; print('JSON OK')"
shellcheck hooks/*.sh init.sh || echo "install shellcheck to verify"
```
Expected: tests PASS, `JSON OK`, no shellcheck errors.

- [ ] **Step 5: Commit**

```bash
git add .github/
git commit -m "ci: tests + JSON validation + shellcheck; issue templates"
```

### Task 21: Publish

- [ ] **Step 1: Confirm the GitHub repo name is free** (user action)

Suggest the user run: `! gh repo view Rishabh-Choudhry/anchor-memory` (expect "not found" = available) — or check on github.com. **Do not create the remote without the user's explicit go-ahead.**

- [ ] **Step 2: Tag and create the public repo** (only after user confirms)

```bash
cd /Users/rishabhc/workspaces/anchor-memory
git tag v0.1.0
gh repo create Rishabh-Choudhry/anchor-memory --public --source=. --remote=origin --push
git push origin v0.1.0
```

- [ ] **Step 3: Flip on the GitHub "Template repository" setting**

```bash
gh repo edit Rishabh-Choudhry/anchor-memory --template=true
```

- [ ] **Step 4: Add discovery topics**

```bash
gh repo edit Rishabh-Choudhry/anchor-memory \
  --add-topic claude-code --add-topic agent-memory --add-topic codex \
  --add-topic cursor --add-topic gemini --add-topic llm --add-topic ai-agents
```

- [ ] **Step 5: Verify published state** — repo is public, template bit on, CI green on the default branch, README renders, one-line install string in README matches the real owner/repo.

---

## Self-Review (completed during planning)

- **Spec coverage:** every spec §5 component maps to a task — machinery (T3–T6), templates (T7–T10), instruction templates incl. karpathy section (T7), keystone skill (T11–T13), workflow skills (T14–T15), multi-agent packaging (T16–T17), README/philosophy/anchor-spec (T2,T9,T19), CI/LICENSE/issue templates (T1,T20), init.sh (T12). Gap analysis items N1–N9 all covered.
- **Placeholder scan:** the `{{...}}` tokens are intentional template variables (substituted in T11/T12), not plan placeholders. No "TBD/TODO" steps.
- **Type/name consistency:** `_files_from_config` (T3) used in T3 main + tested in T4; hook file names consistent across T5/T6/T10/T12; plugin name `anchor-memory` consistent across all manifests (T16/T17) and README (T19).
- **Open risk noted in-plan:** the FACTS.md example anchor (T8) references `README.md`; T13 verifies and instructs fixing the example if it doesn't behave as documented.
