# Security Policy

## Reporting a vulnerability

Please report security issues **privately** using GitHub's **"Report a vulnerability"**
button on this repository's **Security** tab (GitHub Security Advisories). Do not open a
public issue for security reports. We aim to acknowledge reports within a few days.

## Supported versions

The latest `0.1.x` release receives security fixes.

## What Anchor runs on your machine (trust surface)

Anchor installs hooks that execute automatically during Claude Code sessions, with your
user privileges. By design they are minimal and auditable:

- **No network calls.** Nothing is sent anywhere.
- **Read-only git** plus writing a single file inside your repo:
  `.anchor/session-state.md` (gitignored). No writes outside the repo.
- **No `eval` of repository content.** `scripts/memory_lint.py` only parses JSON/CSV and
  does string matching — it never executes file contents.
- Hooks are **advisory** and never block your session.

You can audit everything in `hooks/` and `scripts/memory_lint.py` before installing.
