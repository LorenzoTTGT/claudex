#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$ROOT_DIR/codex"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
ORCA_CODEX_HOME="${ORCA_CODEX_HOME:-$HOME/Library/Application Support/orca/codex-runtime-home/home}"
SYNC_ORCA="${CLAUDEX_SYNC_ORCA_CODEX:-1}"

usage() {
  cat <<'EOF'
Usage: sync-codex-orca.sh [--codex-only]

Install the repo-backed Claudex-aligned Codex workflow files into:
  - ~/.codex
  - Orca's isolated Codex runtime home, when present or enabled

Environment overrides:
  CODEX_HOME               Target Codex home (default: ~/.codex)
  ORCA_CODEX_HOME          Target Orca Codex runtime home
  CLAUDEX_SYNC_ORCA_CODEX  Set to 0 to skip Orca runtime sync
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex-only) SYNC_ORCA=0; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[[ -f "$SOURCE_DIR/AGENTS.md" ]] || { echo "Missing $SOURCE_DIR/AGENTS.md" >&2; exit 1; }
[[ -d "$SOURCE_DIR/agents" ]] || { echo "Missing $SOURCE_DIR/agents" >&2; exit 1; }
[[ -d "$SOURCE_DIR/skills" ]] || { echo "Missing $SOURCE_DIR/skills" >&2; exit 1; }

sync_tree() {
  local destination="$1"
  mkdir -p "$destination" "$destination/agents" "$destination/skills"
  install -m 644 "$SOURCE_DIR/AGENTS.md" "$destination/AGENTS.md"

  find "$destination/agents" -maxdepth 1 -type f \( -name 'claudex-*.toml' -o -name 'worker.toml' -o -name 'worker_high.toml' -o -name 'explorer.toml' -o -name 'clerical.toml' -o -name 'architect.toml' -o -name 'default.toml' \) -delete
  find "$SOURCE_DIR/agents" -maxdepth 1 -type f -name '*.toml' -print0 | while IFS= read -r -d '' file; do
    install -m 644 "$file" "$destination/agents/$(basename "$file")"
  done

  find "$SOURCE_DIR/skills" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' skill; do
    local name
    name="$(basename "$skill")"
    rm -rf "$destination/skills/$name"
    mkdir -p "$destination/skills/$name"
    cp -R "$skill/." "$destination/skills/$name/"
  done
}

patch_config() {
  local config_file="$1"
  mkdir -p "$(dirname "$config_file")"
  python3 - "$config_file" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ''
if '[agents]' not in text:
    if text and not text.endswith('\n'):
        text += '\n'
    text += '\n[agents]\nmax_threads = 3\nmax_depth = 1\n'
else:
    start = text.index('[agents]')
    next_match = re.search(r'(?m)^\[[^\n]+\]', text[start + len('[agents]'):])
    end = start + len('[agents]') + next_match.start() if next_match else len(text)
    section = text[start:end]
    if re.search(r'(?m)^max_threads\s*=', section):
        section = re.sub(r'(?m)^max_threads\s*=.*$', 'max_threads = 3', section, count=1)
    else:
        if not section.endswith('\n'):
            section += '\n'
        section += 'max_threads = 3\n'
    if not re.search(r'(?m)^max_depth\s*=', section):
        if not section.endswith('\n'):
            section += '\n'
        section += 'max_depth = 1\n'
    text = text[:start] + section + text[end:]
path.write_text(text)
PY
}

sync_tree "$CODEX_HOME"
patch_config "$CODEX_HOME/config.toml"
echo "Claudex: synced Codex workflow config to $CODEX_HOME"

if [[ "$SYNC_ORCA" != "0" ]]; then
  sync_tree "$ORCA_CODEX_HOME"
  patch_config "$ORCA_CODEX_HOME/config.toml"
  echo "Claudex: synced Orca Codex workflow config to $ORCA_CODEX_HOME"
fi
