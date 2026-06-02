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
