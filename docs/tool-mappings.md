# Tool-name equivalents across agents

| Concept | Claude Code | Codex | Cursor | Gemini CLI |
|---------|-------------|-------|--------|------------|
| Read file | Read | read_file | read | read_file |
| Edit file | Edit | apply_patch | edit | edit |
| Search text | Grep | grep/ripgrep | grep | search |
| Run shell | Bash | shell | terminal | run_shell_command |
| List dir | Glob/LS | list | list | list_directory |

AGENTS.md is the shared instruction file; this table lets one set of
instructions read naturally regardless of the agent's native tool names.
