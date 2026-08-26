#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/claudex"
BIN_HOME="$HOME/.local/bin"
AGENT_HOME="$HOME/.claude/agents"
CONFIG_FILE="$CONFIG_HOME/cliproxyapi.yaml"
TOKEN_FILE="$CONFIG_HOME/token"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
ORCA_HOME_EXPLICIT=0
[[ -z "${ORCA_CODEX_HOME+x}" ]] || ORCA_HOME_EXPLICIT=1
ORCA_CODEX_HOME="${ORCA_CODEX_HOME:-$HOME/Library/Application Support/orca/codex-runtime-home/home}"
SYNC_ORCA="${CLAUDEX_SYNC_ORCA_CODEX:-auto}"

fail() { printf 'Claudex local verification failed: %s\n' "$*" >&2; exit 1; }

for command_name in claude cliproxyapi cmp codex curl find grep python3 sort; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is unavailable"
done

[[ -x "$BIN_HOME/claudex" ]] || fail "$BIN_HOME/claudex is missing or not executable"
[[ -x "$BIN_HOME/claudex-review-receipt" ]] || fail "$BIN_HOME/claudex-review-receipt is missing or not executable"
[[ -x "$BIN_HOME/claudex-usage-efficiency" ]] || fail "$BIN_HOME/claudex-usage-efficiency is missing or not executable"
[[ -r "$CONFIG_FILE" && -r "$TOKEN_FILE" ]] || fail "proxy config/token pair is incomplete"
! grep -Fq '__CLAUDEX_LOCAL_TOKEN__' "$CONFIG_FILE" || fail "proxy token placeholder was not replaced"
TOKEN="$(<"$TOKEN_FILE")"
[[ -n "$TOKEN" ]] || fail "local proxy token is empty"
grep -Fq -- "$TOKEN" "$CONFIG_FILE" || fail "proxy config and local token do not match"

python3 - "$CONFIG_HOME" "$CONFIG_FILE" "$TOKEN_FILE" <<'PY'
import os, stat, sys
for path, expected in ((sys.argv[1], 0o700), (sys.argv[2], 0o600), (sys.argv[3], 0o600)):
    actual = stat.S_IMODE(os.stat(path).st_mode)
    if actual != expected:
        raise SystemExit(f"Claudex local verification failed: {path} mode is {actual:o}, expected {expected:o}")
PY

cmp -s "$ROOT_DIR/prompts/terra-routing.md" "$CONFIG_HOME/terra-routing.md" || fail "routing prompt does not match the repository source"
for agent in claudex-terra claudex-implementer claudex-luna claudex-sol claudex-sol-review claudex-frontend; do
  cmp -s "$ROOT_DIR/agents/$agent.md" "$AGENT_HOME/$agent.md" || fail "Claude agent $agent does not match the repository source"
done
verify_codex_tree() {
  local destination="$1" label="$2" source relative
  cmp -s "$ROOT_DIR/codex/AGENTS.md" "$destination/AGENTS.md" || fail "$label policy does not match the repository source"
  grep -Fq 'max_threads = 3' "$destination/config.toml" || fail "$label subagent thread cap is missing"
  grep -Fq 'max_depth = 1' "$destination/config.toml" || fail "$label subagent depth cap is missing"

  while IFS= read -r source; do
    relative="${source#"$ROOT_DIR/codex/agents/"}"
    cmp -s "$source" "$destination/agents/$relative" || fail "$label agent $relative does not match the repository source"
  done < <(find "$ROOT_DIR/codex/agents" -maxdepth 1 -type f -name '*.toml' | sort)

  while IFS= read -r source; do
    relative="${source#"$ROOT_DIR/codex/skills/"}"
    cmp -s "$source" "$destination/skills/$relative" || fail "$label skill $relative does not match the repository source"
  done < <(find "$ROOT_DIR/codex/skills" -type f | sort)
}

verify_codex_tree "$CODEX_HOME" "Codex"
if [[ "$SYNC_ORCA" == "1" || ( "$SYNC_ORCA" == "auto" && ( "$ORCA_HOME_EXPLICIT" == "1" || -d "$ORCA_CODEX_HOME" ) ) ]]; then
  verify_codex_tree "$ORCA_CODEX_HOME" "Orca Codex"
fi

printf 'Claudex: local installation files and configuration verified.\n'
printf 'Claudex: OAuth and model access require the separate authenticated smoke test documented in README.md.\n'
