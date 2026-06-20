#!/usr/bin/env bash
set -u
SCAN_PATH="/"
MAX_RESULTS=5000
OUTPUT_DIR=""
usage(){ echo "Usage: file_permission_auditor.sh [--path PATH] [--max-results N] [--output DIR]"; }
while [[ $# -gt 0 ]]; do case "$1" in --path) SCAN_PATH="${2:-/}"; shift 2;; --max-results) MAX_RESULTS="${2:-5000}"; shift 2;; --output) OUTPUT_DIR="${2:-}"; shift 2;; -h|--help) usage; exit 0;; *) echo "Unknown argument: $1" >&2; exit 2;; esac; done
[[ "$MAX_RESULTS" =~ ^[0-9]+$ ]] || { echo "--max-results must be numeric" >&2; exit 2; }
[ -e "$SCAN_PATH" ] || { echo "Path not found: $SCAN_PATH" >&2; exit 1; }
STAMP=$(date +%Y%m%d_%H%M%S); OUTPUT_DIR="${OUTPUT_DIR:-./permission-audit-$STAMP}"; mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/permission-audit.txt"; CSV="$OUTPUT_DIR/findings.csv"; JSON="$OUTPUT_DIR/summary.json"; ERRORS="$OUTPUT_DIR/command-errors.log"; :>"$REPORT"; :>"$ERRORS"
echo 'category,path,owner,group,mode' > "$CSV"
add(){ cat="$1"; path="$2"; owner=$(stat -c '%U' "$path" 2>/dev/null || echo unknown); group=$(stat -c '%G' "$path" 2>/dev/null || echo unknown); mode=$(stat -c '%a' "$path" 2>/dev/null || echo unknown); safe=$(printf '%s' "$path" | sed 's/"/""/g'); printf '"%s","%s","%s","%s","%s"\n' "$cat" "$safe" "$owner" "$group" "$mode" >> "$CSV"; }
{
  echo "Collected: $(date -Is)"; echo "Host: $(hostname -f 2>/dev/null || hostname)"; echo "Scan path: $SCAN_PATH"
} > "$REPORT"
count=0
while IFS= read -r -d '' path; do add world-writable-file "$path"; count=$((count+1)); [ "$count" -ge "$MAX_RESULTS" ] && break; done < <(find "$SCAN_PATH" -xdev -type f -perm -0002 -print0 2>>"$ERRORS")
while IFS= read -r -d '' path; do add world-writable-directory "$path"; count=$((count+1)); [ "$count" -ge "$MAX_RESULTS" ] && break; done < <(find "$SCAN_PATH" -xdev -type d -perm -0002 ! -perm -1000 -print0 2>>"$ERRORS")
while IFS= read -r -d '' path; do add orphaned-owner "$path"; count=$((count+1)); [ "$count" -ge "$MAX_RESULTS" ] && break; done < <(find "$SCAN_PATH" -xdev \( -nouser -o -nogroup \) -print0 2>>"$ERRORS")
while IFS= read -r -d '' path; do add suid-sgid "$path"; count=$((count+1)); [ "$count" -ge "$MAX_RESULTS" ] && break; done < <(find "$SCAN_PATH" -xdev -type f \( -perm -4000 -o -perm -2000 \) -print0 2>>"$ERRORS")
for path in /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/sudoers /etc/ssh/sshd_config /etc/crontab; do [ -e "$path" ] && add sensitive-file "$path"; done
WORLD_FILES=$(awk -F, 'NR>1 && $1 ~ /world-writable-file/{c++} END{print c+0}' "$CSV")
WORLD_DIRS=$(awk -F, 'NR>1 && $1 ~ /world-writable-directory/{c++} END{print c+0}' "$CSV")
ORPHANED=$(awk -F, 'NR>1 && $1 ~ /orphaned-owner/{c++} END{print c+0}' "$CSV")
PRIVILEGED=$(awk -F, 'NR>1 && $1 ~ /suid-sgid/{c++} END{print c+0}' "$CSV")
OVERALL="Healthy"; [ "$WORLD_FILES" -gt 0 ] || [ "$WORLD_DIRS" -gt 0 ] || [ "$ORPHANED" -gt 0 ] && OVERALL="Attention required"
cat >> "$REPORT" <<EOF

World-writable files: $WORLD_FILES
Writable directories without sticky bit: $WORLD_DIRS
Orphaned ownership findings: $ORPHANED
SUID/SGID files: $PRIVILEGED
EOF
cat > "$JSON" <<EOF
{"collected_at":"$(date -Is)","hostname":"$(hostname -f 2>/dev/null || hostname)","scan_path":"$SCAN_PATH","world_writable_files":$WORLD_FILES,"unsafe_writable_directories":$WORLD_DIRS,"orphaned_ownership":$ORPHANED,"suid_sgid_files":$PRIVILEGED,"overall_status":"$OVERALL"}
EOF
printf 'Permission audit completed: %s\n' "$OUTPUT_DIR"
