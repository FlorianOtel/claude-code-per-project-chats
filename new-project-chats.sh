#!/usr/bin/env bash
# ~/.claude/scripts/new-project-chats.sh
#
# Register a Claude Code project in the ~/.claude/chats/ index.
# Creates the per-project chats subdir and named symlinks.
#
# Usage:
#   new-project-chats.sh <absolute-path> [--name <friendly-name>] [--move-from <source-path>] [uuid:session-name ...]
#
# Arguments:
#   absolute-path         Real path to the project working directory (tilde OK).
#                         The Claude Code mangled dir name is derived automatically.
#   --name <name>         Optional friendly name for the chats/ subdir.
#                         Defaults to basename of <absolute-path>.
#                         Use when multiple logical projects share the same path.
#   --move-from <path>    Optional source path. When set, each UUID's .jsonl and
#                         associated metadata dir are physically moved from the source
#                         Claude Code project dir to the destination before registering.
#                         Includes safety checks (no-clobber, source-exists, different dirs)
#                         and integrity checks (size match, source gone, symlink resolves).
#   uuid:name             Zero or more UUID:friendly-name pairs for sessions to register.
#
# Examples:
#   # Code project — name inferred from path
#   new-project-chats.sh /mnt/nfs/Florian/Gin-AI/projects/claude-orchestra \
#     "cbc3b245-c729-40ac-8242-c207bc29de1f:claude-orchestra-full"
#
#   # Generic sessions sharing a path — name overridden
#   new-project-chats.sh ~/Gin-AI/tmp --name general \
#     "uuid1:session-a"
#   new-project-chats.sh ~/Gin-AI/tmp --name troubleshooting \
#     "uuid2:session-b"
#
#   # Move a session from another project dir and register it
#   new-project-chats.sh ~/Gin-AI/tmp --name troubleshooting \
#     --move-from ~/Gin-AI/projects/HomeAI \
#     "9fca84f0-66e9-42f7-be8d-3f7d9329be69:per-project-chats-session"
#
# The script is idempotent: re-running with the same arguments skips existing
# symlinks without erroring.

set -euo pipefail

CHATS_DIR="$HOME/.claude/chats"
PROJECTS_DIR="$HOME/.claude/projects"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <absolute-path> [--name <friendly-name>] [--move-from <source-path>] [uuid:session-name ...]" >&2
  exit 1
fi

# Expand tilde and resolve symlinks so the mangled path matches what Claude Code sees
ABS_PATH="$(realpath -m "${1/#\~/$HOME}")"
shift

# Parse optional flags
PROJECT_NAME=""
MOVE_FROM_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --name)
      [ $# -lt 2 ] && { echo "Error: --name requires an argument" >&2; exit 1; }
      PROJECT_NAME="$2"
      shift 2
      ;;
    --name=*)
      PROJECT_NAME="${1#--name=}"
      shift
      ;;
    --move-from)
      [ $# -lt 2 ] && { echo "Error: --move-from requires an argument" >&2; exit 1; }
      MOVE_FROM_PATH="$(realpath -m "${2/#\~/$HOME}")"
      shift 2
      ;;
    --move-from=*)
      MOVE_FROM_PATH="${1#--move-from=}"
      MOVE_FROM_PATH="$(realpath -m "${MOVE_FROM_PATH/#\~/$HOME}")"
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Default name to basename of path
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME="$(basename "$ABS_PATH")"
fi

# Derive mangled path (replace every / with -)
MANGLED_PATH="${ABS_PATH//\//-}"

PROJECT_DIR="$PROJECTS_DIR/$MANGLED_PATH"
CHATS_PROJECT_DIR="$CHATS_DIR/$PROJECT_NAME"

# Derive source project dir if --move-from was given
SRC_PROJECT_DIR=""
if [ -n "$MOVE_FROM_PATH" ]; then
  SRC_MANGLED="${MOVE_FROM_PATH//\//-}"
  SRC_PROJECT_DIR="$PROJECTS_DIR/$SRC_MANGLED"
fi

# Ensure Claude Code project dir exists
mkdir -p "$PROJECT_DIR"
echo "✓ $PROJECT_DIR"

# Create chats project subdir
mkdir -p "$CHATS_PROJECT_DIR"
echo "✓ $CHATS_PROJECT_DIR"

# Process uuid:name pairs
for pair in "$@"; do
  UUID="${pair%%:*}"
  SESSION_NAME="${pair#*:}"

  # Bare UUID (no :name) — read custom-title from the JSONL (set by /rename)
  if [ "$UUID" = "$SESSION_NAME" ]; then
    if [ -n "$MOVE_FROM_PATH" ]; then
      LOOKUP_JSONL="$SRC_PROJECT_DIR/${UUID}.jsonl"
    else
      LOOKUP_JSONL="$PROJECT_DIR/${UUID}.jsonl"
    fi
    CUSTOM_TITLE="$(grep -o '"customTitle":"[^"]*"' "$LOOKUP_JSONL" 2>/dev/null | tail -1 | sed 's/^"customTitle":"//;s/"$//')"
    if [ -n "$CUSTOM_TITLE" ]; then
      echo "  (auto) session name from /rename: '$CUSTOM_TITLE'"
      SESSION_NAME="$CUSTOM_TITLE"
    else
      echo "Error [$UUID]: no custom title found — use /rename during the session, or pass '$UUID:<session-name>' explicitly." >&2
      exit 1
    fi
  fi

  # --- Move block (only when --move-from is set) ---
  if [ -n "$MOVE_FROM_PATH" ]; then
    SRC_JSONL="$SRC_PROJECT_DIR/${UUID}.jsonl"
    DST_JSONL="$PROJECT_DIR/${UUID}.jsonl"
    SRC_META="$SRC_PROJECT_DIR/${UUID}"
    DST_META="$PROJECT_DIR/${UUID}"

    # Safety checks
    if [ "$SRC_PROJECT_DIR" = "$PROJECT_DIR" ]; then
      echo "Error [$UUID]: source and destination project dirs are the same — nothing to move." >&2
      exit 1
    fi
    if [ ! -f "$SRC_JSONL" ]; then
      echo "Error [$UUID]: source not found: $SRC_JSONL" >&2
      exit 1
    fi
    if [ -e "$DST_JSONL" ]; then
      echo "Error [$UUID]: destination already exists (would clobber): $DST_JSONL" >&2
      exit 1
    fi
    if [ -d "$SRC_META" ] && [ -e "$DST_META" ]; then
      echo "Error [$UUID]: destination metadata dir already exists (would clobber): $DST_META" >&2
      exit 1
    fi

    # Record pre-move state
    SRC_SIZE=$(stat -c%s "$SRC_JSONL")
    HAS_META=0
    [ -d "$SRC_META" ] && HAS_META=1

    echo "  Moving $SRC_JSONL"
    echo "       → $DST_JSONL"
    mv "$SRC_JSONL" "$DST_JSONL"

    if [ "$HAS_META" -eq 1 ]; then
      echo "  Moving $SRC_META/"
      echo "       → $DST_META/"
      mv "$SRC_META" "$DST_META"
    fi

    # Integrity checks
    if [ ! -f "$DST_JSONL" ]; then
      echo "Error [$UUID]: integrity check failed — destination JSONL missing after move." >&2
      exit 1
    fi
    if [ ! -s "$DST_JSONL" ]; then
      echo "Error [$UUID]: integrity check failed — destination JSONL is empty." >&2
      exit 1
    fi
    DST_SIZE=$(stat -c%s "$DST_JSONL")
    if [ "$SRC_SIZE" != "$DST_SIZE" ]; then
      echo "Error [$UUID]: integrity check failed — size mismatch (src=${SRC_SIZE} dst=${DST_SIZE})." >&2
      exit 1
    fi
    if [ -f "$SRC_JSONL" ]; then
      echo "Error [$UUID]: integrity check failed — source JSONL still exists after move." >&2
      exit 1
    fi
    if [ "$HAS_META" -eq 1 ]; then
      if [ ! -d "$DST_META" ]; then
        echo "Error [$UUID]: integrity check failed — destination metadata dir missing after move." >&2
        exit 1
      fi
      if [ -d "$SRC_META" ]; then
        echo "Error [$UUID]: integrity check failed — source metadata dir still exists after move." >&2
        exit 1
      fi
    fi
    if [ "$HAS_META" -eq 1 ]; then
      echo "✓ moved $UUID (${SRC_SIZE} bytes, +metadata dir)"
    else
      echo "✓ moved $UUID (${SRC_SIZE} bytes)"
    fi
  fi

  SESSION_FILE="$PROJECT_DIR/${UUID}.jsonl"
  SYMLINK_PATH="$CHATS_PROJECT_DIR/${SESSION_NAME}.jsonl"
  RELATIVE_TARGET="../../projects/${MANGLED_PATH}/${UUID}.jsonl"

  # Write per-session project name sidecar for claude-history
  # This ensures correct project name display even when multiple projects share the same path
  echo "$PROJECT_NAME" > "$PROJECT_DIR/${UUID}.project-name"

  if [ -z "$MOVE_FROM_PATH" ] && [ ! -f "$SESSION_FILE" ]; then
    echo "Warning: $SESSION_FILE not found — symlink will be dangling" >&2
  fi

  if [ -L "$SYMLINK_PATH" ]; then
    echo "  (exists) $SESSION_NAME.jsonl"
  else
    ln -s "$RELATIVE_TARGET" "$SYMLINK_PATH"
    echo "✓ $SESSION_NAME.jsonl -> $RELATIVE_TARGET"
  fi

  # After a move, the symlink must resolve — hard error if dangling
  if [ -n "$MOVE_FROM_PATH" ] && [ -L "$SYMLINK_PATH" ] && [ ! -e "$SYMLINK_PATH" ]; then
    echo "Error [$UUID]: symlink is dangling after move — something went wrong." >&2
    exit 1
  fi

done

echo ""
echo "Done — ~/.claude/chats/$PROJECT_NAME/ is ready."
