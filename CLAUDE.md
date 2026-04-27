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
---

# Claude Code — Per-Project Chat Session Index

## TL;DR — How to use this

All paths must be **absolute** (or tilde-prefixed — resolved to real paths internally via `realpath`). Symlinks in the path are followed, so `~/Gin-AI/projects/HomeAI` and `/mnt/nfs/Florian/Gin-AI/projects/HomeAI` are equivalent.

---

### Setting up a new project

```bash
~/.claude/scripts/new-project-chats.sh <absolute-path> [--name <friendly-name>] [uuid ...] [uuid:session-name ...]
```

- **Code project** — project name defaults to `basename` of the path:
  ```bash
  new-project-chats.sh /mnt/nfs/Florian/Gin-AI/projects/HomeAI
  ```
- **Generic sessions sharing a path** — use `--name` to distinguish logical projects:
  ```bash
  new-project-chats.sh /mnt/nfs/Florian/Gin-AI/tmp --name troubleshooting
  new-project-chats.sh /mnt/nfs/Florian/Gin-AI/tmp --name general
  ```

The script auto-derives the Claude Code mangled dir name, `mkdir -p`s it, and creates `~/.claude/chats/<name>/`. Idempotent — safe to re-run.

---

### Registering existing sessions

Pass UUIDs as arguments. **Session name defaults to the `customTitle` set by `/rename`** — if present, no `:name` suffix needed:

```bash
# name auto-resolved from /rename customTitle
new-project-chats.sh /mnt/nfs/Florian/Gin-AI/projects/HomeAI \
  "6528daa2-d68b-4dde-8157-5c86c61e0915"

# explicit name override (required if session was never /renamed)
new-project-chats.sh /mnt/nfs/Florian/Gin-AI/projects/HomeAI \
  "abc12345-...:homeai-setup"
```

This creates named symlinks under `~/.claude/chats/HomeAI/`. Session names and project names are consistent with `claude-history` — both read from the same JSONL fields (`customTitle`, `cwd`).

---

### Moving a session from another project dir

Use `--move-from <source-path>` to physically relocate the JSONL (and metadata dir if present) before registering. Session name is auto-resolved from `customTitle` unless overridden:

```bash
new-project-chats.sh /mnt/nfs/Florian/Gin-AI/tmp --name troubleshooting \
  --move-from /mnt/nfs/Florian/Gin-AI/projects/HomeAI \
  "6528daa2-d68b-4dde-8157-5c86c61e0915"
```

Safety checks (source exists, no clobber, dirs differ) and integrity checks (size match, source gone, symlink resolves) run automatically. Fails fast with a clear error on any anomaly.

> **Note:** moving a session changes Claude Code's context loading — the session will no longer appear as prior context when Claude is launched from the original directory. This is usually the intent when reorganising sessions.

---

### What the operator must supply

| What | How to find it |
|---|---|
| **Absolute path** of the project (destination) | The working directory Claude will be launched from for this project |
| **UUID** of the session to register/move | The filename under `~/.claude/projects/<mangled>/`; also the `sessionId` field in the JSONL |
| **Source path** (only for `--move-from`) | Check which `~/.claude/projects/` subdir the UUID file currently lives in; or read the `"cwd"` field from the JSONL |
| **`:session-name`** | Only needed if the session was never renamed with `/rename`; otherwise omit and `customTitle` is used automatically |

---

## Context

Claude Code stores all session transcripts as UUID-named `.jsonl` files under
`~/.claude/projects/<mangled-path>/`. There is no built-in human-readable naming
or cross-project index. This session introduced a convention to address that.

---

## Initial Ask

Move two named chat sessions into a dedicated `~/.claude` project entry for
`~/Gin-AI/projects/claude-orchestra`, and create symlinks under `~/.claude` for
history tracking.

**Sessions found** (both originally in `-mnt-nfs-Florian-Gin-AI-projects-HomeAI/`):

| Session name | UUID |
|---|---|
| `claude-orchestra-full` | `cbc3b245-c729-40ac-8242-c207bc29de1f` |
| `Claude-orchestra-light` | `542aa177-4e85-4134-a14b-7578b555f2e8` |

**Project directory confirmed:** `~/Gin-AI/projects/claude-orchestra` already exists
and is a populated Git repo (scripts, config, docs, agents). No files in it were
touched.

---

## Design Decisions

### Symlink placement
Evaluated three options (`~/.claude/orchestra/`, `~/.claude/chats/`, `~/.claude/`
root). User chose to treat this as the start of a broader migration to a
`~/.claude/chats/` convention covering all projects.

### `~/.claude/chats/` convention
- One subdirectory per project, using the **friendly name** (not the mangled
  Claude Code path)
- Named `.jsonl` symlinks pointing at the real UUID files (relative paths)
- `HISTORY.md` as a master index table across all projects

---

## What Was Built

### Directory structure created

```
~/.claude/chats/
  HISTORY.md                          # master index
  claude-orchestra/
    claude-orchestra-full.jsonl       -> ../../projects/-mnt-nfs-Florian-Gin-AI-projects-claude-orchestra/cbc3b245-c729-40ac-8242-c207bc29de1f.jsonl
    Claude-orchestra-light.jsonl      -> ../../projects/-mnt-nfs-Florian-Gin-AI-projects-claude-orchestra/542aa177-4e85-4134-a14b-7578b555f2e8.jsonl

~/.claude/projects/-mnt-nfs-Florian-Gin-AI-projects-claude-orchestra/
  cbc3b245-c729-40ac-8242-c207bc29de1f.jsonl    # moved from HomeAI project
  542aa177-4e85-4134-a14b-7578b555f2e8.jsonl    # moved from HomeAI project
```

### Files created / updated

| File | Change | Purpose |
|---|---|---|
| `~/.claude/CLAUDE.md` | Added "Chat Session Organization" section | Standing rule for all future sessions |
| `~/.claude/scripts/new-project-chats.sh` | Created (new, executable) | Automates chats/ registration for any new project |
| `~/.claude/chats/HISTORY.md` | Created | Master session index |
| `~/.claude/chats/claude-orchestra/` | Created | Per-project symlink dir |
| `~/.claude/projects/-mnt-nfs-...-claude-orchestra/` | Created | Claude Code project tracking dir |
| memory `project_chats_index.md` | Created | Cross-session recall of the convention |
| memory `MEMORY.md` | Updated | Added pointer to new memory entry |

---

## Helper Script

`~/.claude/scripts/new-project-chats.sh` — idempotent, handles any new project:

```bash
# Usage — paths must be absolute (tilde OK; symlinks resolved automatically)
~/.claude/scripts/new-project-chats.sh \
  <absolute-path> \
  [--name <friendly-name>] \
  [--move-from <source-path>] \
  [uuid ...]            # bare UUID: name from /rename customTitle
  [uuid:session-name ...]  # explicit name override

# Code project — project name from basename, session name from customTitle
~/.claude/scripts/new-project-chats.sh \
  /mnt/nfs/Florian/Gin-AI/projects/claude-orchestra \
  "cbc3b245-c729-40ac-8242-c207bc29de1f" \
  "542aa177-4e85-4134-a14b-7578b555f2e8"

# Generic sessions sharing a path — project name overridden
~/.claude/scripts/new-project-chats.sh \
  /mnt/nfs/Florian/Gin-AI/tmp --name general "uuid1"

~/.claude/scripts/new-project-chats.sh \
  /mnt/nfs/Florian/Gin-AI/tmp --name troubleshooting "uuid2"

# Move a session and register it — name auto-resolved from customTitle
~/.claude/scripts/new-project-chats.sh \
  /mnt/nfs/Florian/Gin-AI/tmp --name troubleshooting \
  --move-from /mnt/nfs/Florian/Gin-AI/projects/HomeAI \
  "6528daa2-d68b-4dde-8157-5c86c61e0915"
```

**Path handling:** tilde and symlinks are resolved via `realpath` before mangling, so the derived project dir always matches what Claude Code uses.

**Session name resolution:** bare UUID → `customTitle` from the JSONL (set by `/rename`); same field used by `claude-history`. Explicit `uuid:name` overrides when no `/rename` was done.

**`--move-from`:** physically relocates the `.jsonl` (and metadata dir if present) from the source project dir before registering the symlink. Includes safety checks (no-clobber, source-exists, dirs differ) and integrity checks (size match, source gone, symlink resolves).

---

## Convention Capture (redundancy by design)

| Layer | File | Lifetime |
|---|---|---|
| Standing rule | `~/.claude/CLAUDE.md` | Every session, every project |
| Automation | `~/.claude/scripts/new-project-chats.sh` | Run manually per new project |
| Cross-session recall | memory `project_chats_index.md` | Loaded when memory is consulted |
| Authoritative registry | `claude-history` CLI | Complete, always up to date |

---

## Workflow for Future Projects

```bash
# 1. (Optional) Move sessions from another project dir (safety + integrity checks included)
#    Either manually:
mv ~/.claude/projects/<source-mangled>/<uuid>.jsonl ~/.claude/projects/<dest-mangled>/
mv ~/.claude/projects/<source-mangled>/<uuid>/       ~/.claude/projects/<dest-mangled>/   # if present

#    Or via the script (recommended — includes safety + integrity checks):
~/.claude/scripts/new-project-chats.sh \
  <absolute-path> [--name <friendly-name>] \
  --move-from <source-path> \
  "<uuid>"          # name from customTitle, or "<uuid>:session-name" to override

# 2. Register in chats/ index without moving
~/.claude/scripts/new-project-chats.sh \
  <absolute-path> \
  [--name <friendly-name>] \
  [uuid ...]        # name from customTitle, or uuid:session-name to override
```
