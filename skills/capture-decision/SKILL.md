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
