---
title: "Claude Code — Per-Project Chat Session Index (chats/ convention)"
date: 2026-04-25
created_by: Claude Code (Claude Sonnet 4.6)
updated_by: Claude Code (Claude Sonnet 4.6)
updated_on: 2026-04-27
context: >
  Session covering the design and implementation of ~/.claude/chats/ as a
  human-readable, per-project index over Claude Code's opaque UUID-based
  session store. Starting point: moving two named orchestra sessions
  (claude-orchestra-full, Claude-orchestra-light) out of the HomeAI project
  and into a dedicated claude-orchestra project entry. Expanded into a
  general convention with a helper script and standing rule in CLAUDE.md.
  Working directory: /mnt/nfs/Florian/Gin-AI/tmp. Model: Claude Sonnet 4.6 (1M).
  Later simplified to pure move-only workflow with UNIX-style arguments.
---

# Claude Code — Per-Project Chat Session Index

## TL;DR — How to use this

Sessions moved to a project directory are tracked via symlinks in `~/.claude/chats/<project>/` and per-session `<uuid>.project-name` sidecar files. This ensures `claude-history` displays the correct project name regardless of where the session now lives.

**Move a session:**

```bash
cd ~/Gin-AI/projects/target-project

# Use the full path to the source JSONL file found in claude-history or ~/.claude/projects/
project-chats.sh --src /path/to/uuid.jsonl
```

---

## How It Works

### Directory structure

```
~/.claude/chats/
  <project-name>/
    <session-name>.jsonl    → symlink to session in ~/.claude/projects/

~/.claude/projects/<mangled-path>/
  <uuid>.jsonl              # session transcript (moved here)
  <uuid>.project-name       # sidecar: contains the project name for display
  <uuid>/                   # metadata dir (if present, moved with JSONL)
```

### The script: `project-chats.sh`

Single purpose: **move a Claude Code session from one project to another.**

```bash
project-chats.sh --src <path/to/uuid.jsonl> [--dst <dir>] [--dst-project <name>] [--dst-name <name>]

  --src <file>           Full path to source JSONL session file (required)
  --dst <dir>            Destination project directory (default: current directory)
  --dst-project <name>   Project name for claude-history display (default: basename of --dst)
  --dst-name <name>      Symlink name in ~/.claude/chats/<project>/ (default: customTitle → UUID)
```

### What happens when you run it

1. **Validates** source JSONL exists and is readable
2. **Extracts** UUID from filename
3. **Derives** source/destination project directories (Claude Code's mangled paths)
4. **Guard check**: source and destination must be different (no-op protection)
5. **Moves** JSONL file from source to destination
6. **Moves** metadata directory if present (same folder as JSONL, named `<uuid>/`)
7. **Integrity checks**: size match, source removed, destination valid
8. **Writes** `<uuid>.project-name` sidecar with the project name
9. **Creates** `~/.claude/chats/<project>/` subdir
10. **Creates** symlink: `~/.claude/chats/<project>/<session-name>.jsonl`

---

## Usage Examples

### Basic: move to current project (default)

```bash
cd ~/Gin-AI/projects/HomeAI

# Get the path from claude-history or list it manually
project-chats.sh --src ~/.claude/projects/-mnt-nfs-Florian-Gin-AI-tmp/abc12345-...jsonl

# Session is now moved to HomeAI, symlink created, sidecar written
# claude-history shows it under "HomeAI"
```

### Move with explicit destination project

```bash
project-chats.sh \
  --src ~/.claude/projects/-mnt-nfs-Florian-Gin-AI-projects-HomeAI/abc123.jsonl \
  --dst ~/Gin-AI/projects/claude-orchestra
```

### Move with custom session display name

```bash
project-chats.sh \
  --src ~/.claude/projects/-mnt-nfs-Florian-Gin-AI-tmp/uuid.jsonl \
  --dst ~/Gin-AI/projects/HomeAI \
  --dst-project homeai \
  --dst-name "setup-session"
```

In this case:
- Session is moved to HomeAI
- Project displays as "homeai" in `claude-history`
- Symlink filename is "setup-session.jsonl"
- If session has a `customTitle` from `/rename`, it's preserved in the JSONL (but not used for display override)

---

## How `claude-history` uses the sidecars

When `claude-history` loads sessions, it reads:

1. **Project name** — from `<uuid>.project-name` sidecar (takes priority)
2. **Session title** — from `customTitle` field in JSONL (updated when you `/rename`)

The sidecar ensures moved sessions show the correct project name. The `customTitle` is the live source of truth for session display names and updates automatically when `/rename` is used.

---

## Safety and integrity

All moves include:

- **Pre-move guards**: source exists, destination differs from source, no clobber
- **Atomic move**: JSONL + metadata directory moved together
- **Integrity checks**: file size match, source removed, destination valid, symlink resolves
- **Explicit feedback**: every step printed with ✓/✗ so you can verify success

---

## Convention Capture

| Layer | File | Purpose |
|---|---|---|
| Standing rule | `~/.claude/CLAUDE.md` | Global per-project session management |
| Automation | `~/.claude/scripts/project-chats.sh` | Move sessions with one command |
| Authoritative registry | `claude-history` CLI | Complete, always up to date |

---

## When you resume and `/rename` a moved session

1. Session is resumed from its new location ✓
2. `/rename` is issued → Claude Code updates `customTitle` in the JSONL ✓
3. `claude-history` next time shows the updated title ✓
4. Symlink name stays as-is (cosmetic — you can re-run `project-chats.sh --src ... --dst-name ...` to update it)

---

## Workflow for moving sessions between projects

```bash
# 1. Find the session in claude-history
claude-history --show-path
# Output: ~/.claude/projects/<mangled>/<uuid>.jsonl

# 2. Move it to the target project directory
cd ~/Gin-AI/projects/TargetProject
project-chats.sh --src <full-path-from-above>

# 3. That's it! Session is now in TargetProject
#    - Symlink created in ~/.claude/chats/TargetProject/
#    - Sidecar written with project name
#    - claude-history will show it under TargetProject
```
