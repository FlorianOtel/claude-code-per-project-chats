#!/usr/bin/env bash
# ~/.claude/scripts/project-chats.sh
#
# Move a Claude Code session to a project directory and register it in ~/.claude/chats/
#
# Usage:
#   project-chats.sh --src <path/to/uuid.jsonl> [--dst-dir <dir>] [--dst-project <name>] [--dst-name <name>]
#
# Arguments:
#   --src <file>           Path to source JSONL session file (required).
#                          Must be an absolute path to <uuid>.jsonl in ~/.claude/projects/<mangled>/
#   --dst-dir <dir>        Destination project directory (default: current working directory).
#                          Session is moved from source Claude Code project dir to this directory's mangled path.
#   --dst-project <name>   Project name displayed in claude-history and used for ~/.claude/chats/ grouping.
#                          Default: basename of --dst-dir directory.
#   --dst-name <name>      Symlink filename in ~/.claude/chats/<project>/.
#                          Default: customTitle from the JSONL, fallback to UUID if no title set.
#
# Examples:
#   # Move a session to HomeAI project (from current directory)
#   cd ~/Gin-AI/projects/HomeAI
#   project-chats.sh --src ~/.claude/projects/-mnt-nfs-Florian-Gin-AI-tmp/abc123.jsonl
#
#   # Move to HomeAI with explicit project and session names
#   project-chats.sh \
#     --src ~/.claude/projects/-mnt-nfs-Florian-Gin-AI-tmp/abc123.jsonl \
#     --dst-dir ~/Gin-AI/projects/HomeAI \
#     --dst-project homeai \
#     --dst-name "setup-session"
#
# Safety checks:
#   - Source JSONL must exist and be a regular file
#   - Destination directory must differ from source directory (no-op guard)
#   - No clobber at destination
#   - Metadata directory (if present) migrated atomically with JSONL
#   - Integrity checks: size match, source removed, destination valid

set -euo pipefail

CHATS_BASE="$HOME/.claude/chats"
PROJECTS_BASE="$HOME/.claude/projects"

# Show help if no arguments
if [ $# -eq 0 ]; then
  cat >&2 << 'EOF'
Usage: project-chats.sh --src <path/to/uuid.jsonl> [--dst-dir <dir>] [--dst-project <name>] [--dst-name <name>]

  --src <file>           Path to source JSONL session file (required)
  --dst-dir <dir>        Destination project directory (default: current directory)
  --dst-project <name>   Project name for claude-history (default: basename of --dst-dir)
  --dst-name <name>      Session symlink name (default: customTitle from JSONL, fallback: UUID)

Examples:
  cd ~/Gin-AI/projects/HomeAI
  project-chats.sh --src ~/.claude/projects/-mnt-nfs-Florian-Gin-AI-tmp/abc123.jsonl

  project-chats.sh \
    --src ~/.claude/projects/-mnt-nfs-Florian-Gin-AI-tmp/abc123.jsonl \
    --dst-dir ~/Gin-AI/projects/HomeAI \
    --dst-project homeai \
    --dst-name "session-name"
EOF
  exit 1
fi

# Parse arguments
SRC_JSONL=""
DST_DIR="$PWD"
DST_PROJECT=""
DST_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --src)
      [ $# -lt 2 ] && { echo "Error: --src requires an argument" >&2; exit 1; }
      SRC_JSONL="$2"
      shift 2
      ;;
    --src=*)
      SRC_JSONL="${1#--src=}"
      shift
      ;;
    --dst-dir)
      [ $# -lt 2 ] && { echo "Error: --dst-dir requires an argument" >&2; exit 1; }
      DST_DIR="$2"
      shift 2
      ;;
    --dst-dir=*)
      DST_DIR="${1#--dst-dir=}"
      shift
      ;;
    --dst-project)
      [ $# -lt 2 ] && { echo "Error: --dst-project requires an argument" >&2; exit 1; }
      DST_PROJECT="$2"
      shift 2
      ;;
    --dst-project=*)
      DST_PROJECT="${1#--dst-project=}"
      shift
      ;;
    --dst-name)
      [ $# -lt 2 ] && { echo "Error: --dst-name requires an argument" >&2; exit 1; }
      DST_NAME="$2"
      shift 2
      ;;
    --dst-name=*)
      DST_NAME="${1#--dst-name=}"
      shift
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Validate --src is provided
if [ -z "$SRC_JSONL" ]; then
  echo "Error: --src is required" >&2
  exit 1
fi

# Expand paths (realpath to follow symlinks)
SRC_JSONL="$(realpath -m "$SRC_JSONL")"
DST_DIR="$(realpath -m "$DST_DIR")"

# Validate --src exists and is a file
if [ ! -f "$SRC_JSONL" ]; then
  echo "Error: source file not found: $SRC_JSONL" >&2
  exit 1
fi

# Extract UUID from filename
UUID="$(basename "$SRC_JSONL" .jsonl)"
if ! [[ "$UUID" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
  echo "Error: filename '$UUID.jsonl' does not look like a valid UUID" >&2
  exit 1
fi

SRC_DIR="$(dirname "$SRC_JSONL")"
SRC_META="$SRC_DIR/$UUID"

# Derive destination mangled path
DST_MANGLED="${DST_DIR//\//-}"
DST_PROJECTS_DIR="$PROJECTS_BASE/$DST_MANGLED"
DST_JSONL="$DST_PROJECTS_DIR/${UUID}.jsonl"
DST_META="$DST_PROJECTS_DIR/$UUID"

# Guard: if --dst-dir doesn't exist, require explicit --dst-project
if [ ! -d "$DST_DIR" ]; then
  if [ -z "$DST_PROJECT" ]; then
    cat >&2 << EOF
Error: --dst-dir path does not exist, and --dst-project not specified

  --dst-dir: $DST_DIR

If this is a typo, check the path and try again.
If you intend to create a virtual project (directory NOT created on disk):
  - Add: --dst-project <name>
  - This registers the session under a logical project name
  - Claude Code's ~/.claude/projects/<mangled>/ dir is created automatically
  - But ~/Gin-AI/projects/<name>/ is NOT created

Example:
  project-chats.sh --src <uuid.jsonl> \\
    --dst-dir ~/Gin-AI/projects/troubleshooting \\
    --dst-project troubleshooting
EOF
    exit 1
  fi
fi

# Default project name (when --dst exists or --dst-project was provided)
if [ -z "$DST_PROJECT" ]; then
  DST_PROJECT="$(basename "$DST_DIR")"
fi

# Check: source and destination dirs must differ
if [ "$SRC_DIR" = "$DST_PROJECTS_DIR" ]; then
  echo "Error: source and destination are the same directory — nothing to move" >&2
  exit 1
fi

# Safety checks: no clobber
if [ -e "$DST_JSONL" ]; then
  echo "Error: destination JSONL already exists (would clobber): $DST_JSONL" >&2
  exit 1
fi

if [ -d "$SRC_META" ] && [ -e "$DST_META" ]; then
  echo "Error: destination metadata dir would be clobbered: $DST_META" >&2
  exit 1
fi

# Derive session name: customTitle from JSONL (if exists), fallback to UUID, override with --dst-name
if [ -z "$DST_NAME" ]; then
  # Try to extract customTitle from the JSONL
  CUSTOM_TITLE="$(grep -o '"customTitle":"[^"]*"' "$SRC_JSONL" 2>/dev/null | tail -1 | sed 's/^"customTitle":"//;s/"$//' || echo "")"
  if [ -n "$CUSTOM_TITLE" ]; then
    DST_NAME="$CUSTOM_TITLE"
  else
    DST_NAME="$UUID"
  fi
fi

# Record source state (for integrity checks)
SRC_SIZE=$(stat -c%s "$SRC_JSONL" 2>/dev/null || stat -f%z "$SRC_JSONL" 2>/dev/null || echo "0")
HAS_META=0
[ -d "$SRC_META" ] && HAS_META=1

echo "Moving session $UUID"
echo "  Project: $DST_PROJECT"
echo "  Display: $DST_NAME"
if [ "$HAS_META" -eq 1 ]; then
  echo "  With metadata dir"
fi
echo ""

# Create destination project dir
mkdir -p "$DST_PROJECTS_DIR"
echo "✓ $DST_PROJECTS_DIR"

# Move JSONL
echo "  Moving $SRC_JSONL"
echo "       → $DST_JSONL"
mv "$SRC_JSONL" "$DST_JSONL"

# Move metadata dir if present
if [ "$HAS_META" -eq 1 ]; then
  echo "  Moving $SRC_META/"
  echo "       → $DST_META/"
  mv "$SRC_META" "$DST_META"
fi

# Integrity checks
echo ""
echo "Integrity checks:"

if [ ! -f "$DST_JSONL" ]; then
  echo "✗ FAILED: destination JSONL missing" >&2
  exit 1
fi
echo "  ✓ destination JSONL exists"

if [ ! -s "$DST_JSONL" ]; then
  echo "✗ FAILED: destination JSONL is empty" >&2
  exit 1
fi
echo "  ✓ destination JSONL non-empty"

DST_SIZE=$(stat -c%s "$DST_JSONL" 2>/dev/null || stat -f%z "$DST_JSONL" 2>/dev/null || echo "0")
if [ "$SRC_SIZE" != "$DST_SIZE" ]; then
  echo "✗ FAILED: size mismatch (src=$SRC_SIZE dst=$DST_SIZE)" >&2
  exit 1
fi
echo "  ✓ size match ($SRC_SIZE bytes)"

if [ -f "$SRC_JSONL" ]; then
  echo "✗ FAILED: source JSONL still exists" >&2
  exit 1
fi
echo "  ✓ source JSONL removed"

if [ "$HAS_META" -eq 1 ]; then
  if [ ! -d "$DST_META" ]; then
    echo "✗ FAILED: destination metadata dir missing" >&2
    exit 1
  fi
  echo "  ✓ metadata dir moved"
  
  if [ -d "$SRC_META" ]; then
    echo "✗ FAILED: source metadata dir still exists" >&2
    exit 1
  fi
fi

# Write per-session project name sidecar
SIDECAR="$DST_PROJECTS_DIR/${UUID}.project-name"
echo "$DST_PROJECT" > "$SIDECAR"
echo "✓ $SIDECAR"

# Create chats/ project subdir
CHATS_PROJECT_DIR="$CHATS_BASE/$DST_PROJECT"
mkdir -p "$CHATS_PROJECT_DIR"
echo "✓ $CHATS_PROJECT_DIR"

# Create symlink
SYMLINK="$CHATS_PROJECT_DIR/${DST_NAME}.jsonl"
RELATIVE_TARGET="../../projects/${DST_MANGLED}/${UUID}.jsonl"

if [ -L "$SYMLINK" ]; then
  echo "  (exists) $DST_NAME.jsonl"
else
  ln -s "$RELATIVE_TARGET" "$SYMLINK"
  echo "✓ $DST_NAME.jsonl -> $RELATIVE_TARGET"
fi

# Final verification
if [ -L "$SYMLINK" ] && [ ! -e "$SYMLINK" ]; then
  echo "✗ FAILED: symlink is dangling after move" >&2
  exit 1
fi

echo ""
echo "✓ Done — session moved to $DST_PROJECT"
