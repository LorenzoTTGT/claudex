#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/claudex/install-backups"
HELPER="$ROOT_DIR/scripts/install-state.py"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/uninstall.sh --list-backups
  ./scripts/uninstall.sh --restore-backup BACKUP_ID
  ./scripts/uninstall.sh --restore-original

Restoration is refused if any managed path changed after the selected install.
Shared dependencies, proxy config/token, OAuth credentials, telemetry, and unknown
files are never removed.
EOF
}

[[ -f "$HELPER" ]] || { echo "Missing install-state helper: $HELPER" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo 'python3 is required for conservative restore/uninstall.' >&2; exit 1; }

case "${1:-}" in
  --list-backups)
    [[ $# -eq 1 ]] || { usage >&2; exit 2; }
    python3 "$HELPER" --state-root "$STATE_ROOT" list
    ;;
  --restore-backup)
    [[ $# -eq 2 ]] || { usage >&2; exit 2; }
    python3 "$HELPER" --state-root "$STATE_ROOT" restore-backup "$2"
    ;;
  --restore-original)
    [[ $# -eq 1 ]] || { usage >&2; exit 2; }
    python3 "$HELPER" --state-root "$STATE_ROOT" restore-original
    ;;
  *) usage >&2; exit 2 ;;
esac
