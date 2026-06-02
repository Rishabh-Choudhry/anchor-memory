# Anchor — Verifiable Memory & Working Discipline for Coding Agents

**Status:** Design (approved direction: plugin-first, scaffold-as-output)
**Date:** 2026-06-02
**Author:** spin-off planning from `workout_mvp` tooling
**Note:** This is a *planning doc* for a **separate, independent public repo**. Nothing here ships inside `workout_mvp`. Working name **Anchor** (renameable; the hook + `@meta` "anchors" narrative motivates it).

---

## 1. One-line pitch

> **Anchor** is the memory system for coding agents that catches itself lying. Agents accumulate a verifiable, self-policing project ledger — facts and decisions carry machine-checkable `@meta` anchors, and a linter + hooks flag any entry that drifts from the live repo before the agent trusts it.

Tagline for social/README: *"Stop your agent re-proposing failed ideas and quoting stale facts."*

## 2. The core thesis (template vs plugin, resolved)

Our assets are **two artifacts with opposite natures**:

| | Memory **content** | Memory **machinery** |
|---|---|---|
| Examples | `CLAUDE.md`, `FACTS.md`, `decisions.md`, `status.md`, fact files | `memory_lint.py`, 3 hooks, `@meta` anchor spec, skills |
| Nature | Stateful, per-project, repo-resident, diverges immediately | Stateless, identical across projects, improves centrally |
| Right delivery | **Scaffold** (lands in the repo, then lives there) | **Plugin** (one-line install, auto-updates) |

**Decision: plugin-first, scaffold-as-output.** The plugin is the product and the front door; the template/scaffold is what the plugin *generates and polices*. We also flip the GitHub-template bit + vendor `init.sh` so non-plugin users (pure Codex/Cursor, or plugin-averse) run the same scaffold logic. One repo serves both.

Rationale: plugins compound (one repo, one star count, one-line install, central updates via marketplace); forks fragment and rot. Our differentiator (verifiable self-falsifying memory) *is* machinery, and machinery is what plugins package. "Another CLAUDE.md starter" is a crowded category; "verifiable agent memory" is a category of one.

## 3. Locked decisions (from brainstorming)

- **Multi-agent first-class** — Claude + AGENTS.md + GEMINI.md + tool-name mappings; superpowers-style parallel plugin manifests.
- **Two-tier memory** — in-repo git-tracked ledger **+** per-user auto-memory index; all paths config-driven, zero hardcoded absolute paths.
- **Skills: memory + light workflow** — bootstrap/init, capture-decision, update-status, recall, generalized review-pr, session-wrapup.
- **Adoption** — evidence-based: mirror karpathy/superpowers (`/plugin marketplace add <user>/<repo>`, MIT, keyword-rich `plugin.json`, README-as-landing-page) + GitHub template fallback.

---

## 4. Repository architecture

Single public repo `anchor/`, simultaneously a multi-agent plugin **and** a GitHub template:

```
anchor/
├── README.md                      # social landing page: pitch, 60-sec install, demo gif
├── LICENSE                        # MIT
├── CHANGELOG.md
├── .claude-plugin/
│   ├── marketplace.json           # repo-as-marketplace (source: "./")
│   └── plugin.json                # name, keywords, category, interface{}, skills, hooks
├── .codex-plugin/plugin.json      # multi-agent manifests (shared skills/hooks)
├── .cursor-plugin/plugin.json
├── .opencode/plugins/             # opencode manifest
├── hooks/
│   ├── session-context.sh         # SessionStart: git + status digest (de-hardcoded)
│   ├── memory-integrity-scan.sh   # SessionStart: surface drift only when present
│   ├── memory-integrity-gate.sh   # Stop (advisory): nudge if code changed, memory didn't
│   └── hooks.json                 # hook wiring (referenced by plugin + copied by init)
├── scripts/
│   ├── memory_lint.py             # generalized, stdlib-only, config-driven
│   └── test_memory_lint.py        # ported tests
├── skills/
│   ├── memory-init/SKILL.md       # BOOTSTRAP: interview → scaffold repo files + wire settings
│   ├── capture-decision/SKILL.md  # append a load-bearing decision (+ optional @meta anchor)
│   ├── update-status/SKILL.md     # move items in status.md
│   ├── recall/SKILL.md            # read ledger + run lint before acting
│   ├── review-pr/SKILL.md         # generalized PR review (config-driven checklist)
│   └── session-wrapup/SKILL.md    # end-of-session memory-update ritual
├── templates/                     # the scaffold OUTPUT (what memory-init writes)
│   ├── CLAUDE.md.tmpl
│   ├── AGENTS.md.tmpl
│   ├── GEMINI.md.tmpl
│   ├── anchor.config.json.tmpl    # paths + watch-globs config (de-hardcodes everything)
│   ├── memory/
│   │   ├── FACTS.md.tmpl          # ledger + tried-and-failed firewall (empty skeleton)
│   │   ├── decisions.md.tmpl
│   │   ├── status.md.tmpl
│   │   └── README.md              # how the ledger works
│   ├── auto-memory/
│   │   ├── MEMORY.md.tmpl         # index
│   │   └── fact-file.md.tmpl      # one-fact-per-file w/ frontmatter
│   └── settings.json.fragment     # hook wiring to merge into .claude/settings.json
├── init.sh                        # GitHub-template path: same scaffold logic, no plugin
├── docs/
│   ├── anchor-anchors-spec.md     # the @meta anchor convention (file_exists/json_field/grep/golden_metric)
│   ├── philosophy.md              # why verifiable memory; the two-tier model
│   └── tool-mappings.md           # Claude↔Codex↔Cursor↔Gemini tool-name equivalents
└── .github/
    ├── ISSUE_TEMPLATE/
    └── workflows/ci.yml           # run memory_lint tests + shellcheck hooks
```

---

## 5. Components

### 5.1 Memory machinery (the engine)

**`memory_lint.py` — generalize from `workout_mvp`.** Currently stdlib-only and tested. Changes:
- Read watch-globs + memory dir from `anchor.config.json` instead of assuming repo layout.
- Keep anchor kinds: `file_exists`, `json_field`, `file_grep`, `golden_metric`, plus `supersedes`/duplicate-id integrity and dangling `[[link]]` detection.
- Modes preserved: `--check` (default), `--quiet`, `--json`.

**`@meta` anchor spec (`docs/anchor-anchors-spec.md`).** Document the convention as a first-class, agent-agnostic standard: a memory entry may declare anchors that the linter checks against the live repo; failing anchors mark the entry as drifted/untrusted.

### 5.2 Hooks (de-hardcode — this is required work)

Current hooks have two hardcoded assumptions that **must** be removed:
- `session-context.sh`: absolute `MEMORY_DIR="$HOME/.claude/projects/-Users-...-workout-mvp/memory"`. → resolve from `anchor.config.json` / `$CLAUDE_PROJECT_DIR`.
- `memory-integrity-gate.sh`: hardcoded watch paths `ios/|lib/|training/|scripts/` and ledger paths `memory/decisions.md|FACTS.md`. → read watch-globs + ledger paths from config.

All three stay advisory/non-blocking; integrity-scan stays silent when clean.

### 5.3 Memory templates (the scaffold output — content-free skeletons)

Strip ALL workout-MVP content; keep the *shape*:
- **FACTS.md** — "mandatory first read" ledger with empty *Current facts* table + empty *Tried & failed (anti-repetition firewall)* section + "Last verified" line.
- **decisions.md** — dated, WHY-first, "DO NOT change without discussion" convention, `status: superseded` mechanic.
- **status.md** — phase/checklist skeleton.
- **auto-memory** — `MEMORY.md` index + `fact-file.md` template with `name/description/metadata.type (user|feedback|project|reference)` frontmatter and `[[link]]` convention.

### 5.4 Instruction templates (multi-agent)

Both CLAUDE.md and AGENTS.md templates open with a **"How to work" behavioral section adopted from [andrej-karpathy-skills](https://github.com/forrestchang/andrej-karpathy-skills) (MIT)** — the four principles: *Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution*. This is the behavioral half our template lacked; our project-structure + memory sections compose below it. Attribution: a credit line in each template header + a `CREDITS.md`/`NOTICE` preserving the karpathy MIT notice + a README acknowledgement. (The four principles are inlined so the template is self-contained without requiring the karpathy plugin; we also recommend the plugin in the README for users who want it auto-updated.)

Template layering (top → bottom):
1. **How to work** — karpathy's 4 behavioral principles (inlined, attributed).
2. **Project map** — source-of-truth pointers, build/run, project structure, gotchas. Placeholders (`{{PROJECT_NAME}}`, `{{BUILD_CMD}}`, etc.).
3. **Key decisions (DO NOT change without discussion)** + **mandatory memory-update ritual** + **compaction instructions** — the Anchor differentiator.

- **CLAUDE.md.tmpl** — full layered template above.
- **AGENTS.md.tmpl** — the portable source-of-truth (Codex/Cursor/others read this); CLAUDE.md becomes a thin pointer to it where ecosystems allow, to avoid divergence. Carries the same karpathy "How to work" section.
- **GEMINI.md.tmpl** — Gemini pointer + auto-loaded tool mapping.
- **docs/tool-mappings.md** — Claude↔Codex↔Cursor↔Gemini tool-name equivalents (Read/Edit/Grep/Bash...).
- **CREDITS.md / NOTICE** — preserves the karpathy-skills MIT copyright + link; README "Acknowledgements" section credits it.

### 5.5 Skills (memory + light workflow)

1. **`memory-init`** *(the keystone — new build)*. Interview (project name, language/build cmd, watch-globs, two-tier on/off), then: write CLAUDE.md/AGENTS.md/GEMINI.md, seed `memory/` + `auto-memory/`, write `anchor.config.json`, and **merge hook wiring into `.claude/settings.json`**. Idempotent; safe re-run.
2. **`capture-decision`** — append a decision to `decisions.md` (date + WHY + impact), optionally attach an `@meta` anchor.
3. **`update-status`** — check/move items in `status.md`.
4. **`recall`** — read FACTS/decisions + run `memory_lint --quiet` before proposing architecture/experiments (enforces the firewall).
5. **`review-pr`** — generalized; checklist sourced from `anchor.config.json` (license allowlist, architecture invariants) instead of hardcoded workout rules.
6. **`session-wrapup`** — end-of-session ritual: prompt to update decisions/status, mark superseded entries.

### 5.6 Distribution

- **Plugin (primary):** `marketplace.json` (`source: "./"`) + per-agent `plugin.json`s with shared `./skills/` and `./hooks/`. Install: `/plugin marketplace add <user>/anchor` then `/plugin install anchor`.
- **GitHub template (secondary):** repo "Template" bit on; `init.sh` runs the same scaffold logic for non-plugin users.
- **README:** pitch → 60-second install (both paths) → 30-second "what it does" demo → philosophy link. MIT. Keyword-rich for discovery.

---

## 6. Gap analysis — what's MISSING vs. what's DE-PROJECTED

This is the "make a comprehensive plan to add that" the goal asks for.

### Already have (port + de-project, low effort)
- `memory_lint.py` + tests — **generalize config** (M).
- 3 hooks — **de-hardcode paths** (M, required).
- CLAUDE.md structure, memory ledger shapes, `@meta` convention — **strip content → templates** (M).

### Must build NEW (the real additions)
| # | Item | Why it's missing | Effort |
|---|---|---|---|
| N1 | `memory-init` bootstrap skill | Nothing today scaffolds files into a fresh repo | **L** |
| N2 | `anchor.config.json` schema + loader | The single seam that de-hardcodes hooks + linter + review-pr | M |
| N3 | AGENTS.md / GEMINI.md templates + tool-mappings doc | Today only CLAUDE.md exists; multi-agent is net-new | M |
| N4 | Multi-agent plugin manifests (4×) + marketplace.json | Net-new packaging | M |
| N5 | Universal skills (capture-decision, update-status, recall, session-wrapup) | Current skills are all domain-specific | M |
| N6 | Generalized review-pr (config-driven checklist) | Current one is workout-specific | S |
| N7 | README + philosophy + demo asset | The social landing page; adoption depends on it | M |
| N8 | CI (lint tests + shellcheck), LICENSE, issue templates | Repo hygiene for OSS | S |
| N9 | `init.sh` (template-path scaffold) | Non-plugin adoption path | S |

### Explicitly OUT of scope (YAGNI)
- MCP servers, agents (ios-builder/security-reviewer are domain-specific), Copier `.yml` (plugin auto-update supersedes it), i18n READMEs (later), any workout/ML content.

---

## 7. Phased roadmap

- **M0 — Skeleton & decisions (½ day):** create repo, LICENSE, README stub, `anchor.config.json` schema, file tree.
- **M1 — Engine portable (1 day):** generalize `memory_lint.py` + tests against config; de-hardcode 3 hooks; `hooks.json`. CI green.
- **M2 — Templates (1 day):** content-free CLAUDE/AGENTS/GEMINI + memory ledger + auto-memory skeletons + tool-mappings.
- **M3 — Keystone skill (1–2 days):** `memory-init` scaffolds + wires settings; idempotent; dogfood on a throwaway repo.
- **M4 — Skill set (1 day):** capture-decision, update-status, recall, session-wrapup, generalized review-pr.
- **M5 — Packaging (1 day):** 4 plugin manifests + marketplace.json; verify one-line install on Claude (and at least Codex) locally.
- **M6 — Launch polish (1 day):** README landing page + demo gif, philosophy doc, issue templates, tag v0.1.0, flip template bit, publish.

## 8. Success criteria

- Fresh repo → `/plugin install` → `/memory-init` → working CLAUDE.md + seeded ledger + active hooks in **< 5 minutes**, zero manual path edits.
- `memory_lint` tests pass in CI; hooks pass shellcheck; all paths config-driven (no absolute paths anywhere).
- Drift demo reproducible: rename an anchored file → next session surfaces the drift warning.
- Multi-agent: scaffold produces valid CLAUDE.md + AGENTS.md + GEMINI.md; plugin installs on ≥2 agents.

## 9. Resolved decisions (all locked 2026-06-02)

1. **Name** — brand **Anchor**; repo + plugin slug **`anchor-memory`**. SEO is carried by the GitHub description, topics, and `plugin.json` keywords (*agent memory, claude code, codex, cursor, gemini, ai agent context, llm memory*) + the launch social copy — NOT by the slug. "claude" is deliberately kept out of the name (multi-agent scope + Anthropic trademark guidance); used only as a keyword.
2. **AGENTS.md is the single source of truth**; CLAUDE.md + GEMINI.md are thin pointers to it (carry the karpathy "How to work" section + a pointer to AGENTS.md). Prevents divergence.
3. **`memory-init` is minimal** — interviews only project name + build command; everything else (watch-globs, review checklist, two-tier toggle) gets sensible defaults written to `anchor.config.json` for later editing.
4. **Repo home** — new public repo under the user's GitHub account (Rishabh-Choudhry), independent of `workout_mvp`, created at M0.
