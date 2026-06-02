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
