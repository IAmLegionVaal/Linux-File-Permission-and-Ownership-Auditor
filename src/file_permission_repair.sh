#!/usr/bin/env bash
set -u

TARGET=""
MODE=""
OWNER=""
GROUP=""
SET_STICKY=false
REMOVE_WORLD_WRITE=false
RECURSIVE=false
DRY_RUN=false
ASSUME_YES=false
OUTPUT_DIR=""
FAILURES=0
ACTIONS=0

usage(){ cat <<'EOF'
Usage: file_permission_repair.sh --path PATH [options]

  --mode OCTAL              Set one explicit mode, such as 640 or 750.
  --owner USER              Set one existing owner.
  --group GROUP             Set one existing group.
  --set-sticky              Add the sticky bit to a directory.
  --remove-world-write      Remove world-write permission.
  --recursive               Apply owner/group or world-write removal recursively.
  --dry-run                 Show commands without changing files.
  --yes                     Skip confirmation prompts.
  --output DIR              Save logs, backup metadata and verification output in DIR.
EOF
}
while [ "$#" -gt 0 ]; do case "$1" in
  --path) TARGET="${2:-}"; shift 2;; --mode) MODE="${2:-}"; shift 2;;
  --owner) OWNER="${2:-}"; shift 2;; --group) GROUP="${2:-}"; shift 2;;
  --set-sticky) SET_STICKY=true; shift;; --remove-world-write) REMOVE_WORLD_WRITE=true; shift;;
  --recursive) RECURSIVE=true; shift;; --dry-run) DRY_RUN=true; shift;; --yes) ASSUME_YES=true; shift;;
  --output) OUTPUT_DIR="${2:-}"; shift 2;; -h|--help) usage; exit 0;;
  *) echo "Unknown argument: $1" >&2; usage; exit 2;; esac; done
[ -e "$TARGET" ] && [ ! -L "$TARGET" ] || { echo "Target must exist and must not be a symbolic link." >&2; exit 2; }
if [ -z "$MODE" ] && [ -z "$OWNER" ] && [ -z "$GROUP" ] && ! $SET_STICKY && ! $REMOVE_WORLD_WRITE; then echo "Choose at least one repair action." >&2; exit 2; fi
case "$TARGET" in /|/bin|/sbin|/usr|/etc|/var|/home) $RECURSIVE && { echo "Refusing recursive changes on a top-level system path." >&2; exit 2; };; esac
[ -z "$MODE" ] || [[ "$MODE" =~ ^[0-7]{3,4}$ ]] || { echo "Mode must be a 3- or 4-digit octal value." >&2; exit 2; }
[ -z "$OWNER" ] || id "$OWNER" >/dev/null 2>&1 || { echo "Owner not found: $OWNER" >&2; exit 2; }
[ -z "$GROUP" ] || getent group "$GROUP" >/dev/null 2>&1 || { echo "Group not found: $GROUP" >&2; exit 2; }
$SET_STICKY && [ -d "$TARGET" ] || { $SET_STICKY || true; }
STAMP=$(date +%Y%m%d_%H%M%S); OUTPUT_DIR="${OUTPUT_DIR:-./permission-repair-$STAMP}"; mkdir -p "$OUTPUT_DIR"; LOG="$OUTPUT_DIR/repair.log"; BEFORE="$OUTPUT_DIR/before.txt"; AFTER="$OUTPUT_DIR/after.txt"; : >"$LOG"
log(){ printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
confirm(){ $ASSUME_YES && return 0; read -r -p "$1 [y/N]: " a; case "$a" in y|Y|yes|YES) return 0;; *) return 1;; esac; }
run(){ local d="$1"; shift; ACTIONS=$((ACTIONS+1)); log "$d"; if $DRY_RUN; then printf 'DRY-RUN:' >>"$LOG"; printf ' %q' "$@" >>"$LOG"; printf '\n' >>"$LOG"; return 0; fi; if "$@" >>"$LOG" 2>&1; then log "SUCCESS: $d"; else FAILURES=$((FAILURES+1)); log "WARNING: $d failed"; return 1; fi; }
root(){ local d="$1"; shift; if [ "$(id -u)" -eq 0 ]; then run "$d" "$@"; else run "$d" sudo "$@"; fi; }
collect(){ local f="$1"; { echo "Collected: $(date -Is)"; stat -c '%a %A %U:%G %u:%g %n' "$TARGET" 2>&1; getfacl -p "$TARGET" 2>/dev/null || true; $RECURSIVE && find "$TARGET" -xdev -maxdepth 3 -printf '%m %u:%g %p\n' 2>/dev/null | head -n 500; } >"$f"; }
collect "$BEFORE"; cp "$BEFORE" "$OUTPUT_DIR/original-metadata.txt"
confirm "Apply the selected ownership and permission repairs to $TARGET?" || { log "Repair cancelled."; exit 10; }
RECURSE_ARG=(); $RECURSIVE && RECURSE_ARG=(-R)
if [ -n "$OWNER" ] || [ -n "$GROUP" ]; then SPEC="${OWNER:-}:$GROUP"; [ -n "$OWNER" ] && [ -z "$GROUP" ] && SPEC="$OWNER"; root "Changing ownership on $TARGET" chown "${RECURSE_ARG[@]}" "$SPEC" "$TARGET" || true; fi
[ -z "$MODE" ] || root "Setting mode $MODE on $TARGET" chmod "$MODE" "$TARGET" || true
$SET_STICKY && root "Adding sticky bit to $TARGET" chmod +t "$TARGET" || true
if $REMOVE_WORLD_WRITE; then if $RECURSIVE; then root "Removing world-write permission below $TARGET" chmod -R o-w "$TARGET" || true; else root "Removing world-write permission from $TARGET" chmod o-w "$TARGET" || true; fi; fi
$DRY_RUN || sleep 1; collect "$AFTER"; [ "$FAILURES" -eq 0 ] || exit 20; log "Repair completed successfully. Actions performed: $ACTIONS"
