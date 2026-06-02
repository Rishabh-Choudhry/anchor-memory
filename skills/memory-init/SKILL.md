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
