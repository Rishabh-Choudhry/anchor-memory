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
- **Never lose a session** — a checkpoint hook auto-saves your working state every
  turn (and before compaction) to `.anchor/session-state.md`; `/handoff` records
  intent in `memory/HANDOFF.md`; both surface automatically on your next start.
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
