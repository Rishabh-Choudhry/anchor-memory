---
name: session-wrapup
description: Use at the end of a work session to run the memory ritual — capture decisions, update status, mark superseded entries.
---

# session-wrapup

1. Did any load-bearing decision get made/reversed? → use `capture-decision`.
2. Did phase progress change? → use `update-status`.
3. Any entry now false? → mark `status: superseded` (don't delete history).
4. Run `python3 <linter> --root .`; resolve any DRIFT/BROKEN before ending.
