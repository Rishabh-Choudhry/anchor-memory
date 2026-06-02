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
