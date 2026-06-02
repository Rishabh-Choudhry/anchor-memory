---
name: handoff
description: Use to snapshot where you are so a future session (or you after a rate limit) can resume cleanly — writes memory/HANDOFF.md with goal, what's done, the next step, and open threads. Run often, and before you stop.
---

# handoff

1. Write/refresh `memory/HANDOFF.md` with:
   - **Goal** — what we're trying to achieve right now.
   - **Done** — what's complete this session.
   - **Next step** — the single concrete next action.
   - **Open threads / gotchas** — anything mid-flight or surprising.
   - **Key files** — paths in play.
2. Keep it short and current — overwrite it, don't append a log.
3. This complements `.anchor/session-state.md`, which the checkpoint hook auto-saves
   every turn. HANDOFF.md captures intent (only you know it); session-state.md
   captures reality (git). On resume, trust the git diff if HANDOFF.md looks stale.
