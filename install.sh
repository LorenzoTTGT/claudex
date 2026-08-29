#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/claudex"
BIN_HOME="$HOME/.local/bin"
AGENT_HOME="$HOME/.claude/agents"
CONFIG_FILE="$CONFIG_HOME/cliproxyapi.yaml"
TOKEN_FILE="$CONFIG_HOME/token"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/claudex/install-backups"
STATE_HELPER="$ROOT_DIR/scripts/install-state.py"
SKIP_LOGIN=0
INSTALL_MODE="${CLAUDEX_INSTALL_MODE:-full}"
BACKUP_ID=""
BACKUP_FINALIZED=0

if [[ "${1:-}" == "--skip-login" ]]; then
  SKIP_LOGIN=1
elif [[ -n "${1:-}" ]]; then
  printf 'Usage: %s [--skip-login]\n' "$0" >&2
  exit 2
fi

require_commands() {
  local missing=() command_name
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'Claudex installer prerequisites are missing: %s\n' "${missing[*]}" >&2
    printf 'Nothing was changed. Install the missing commands and rerun the installer.\n' >&2
    exit 1
  fi
}

preflight() {
  case "$(uname -s 2>/dev/null || true)" in
    Darwin|Linux) ;;
    *) printf 'Claudex supports macOS and Linux only. Nothing was changed.\n' >&2; exit 1 ;;
  esac

  require_commands chmod cmp dirname find grep install mkdir openssl python3 sed sort uname
  [[ -x "$STATE_HELPER" || -f "$STATE_HELPER" ]] || {
    printf 'Missing install-state helper: %s\n' "$STATE_HELPER" >&2
    exit 1
  }

  if [[ "$INSTALL_MODE" == "full" ]]; then
    require_commands curl
    [[ -x /bin/bash ]] || { printf '/bin/bash is required. Nothing was changed.\n' >&2; exit 1; }
  elif [[ "$INSTALL_MODE" == "configure-only" ]]; then
    require_commands claude cliproxyapi codex curl
  else
    printf 'Unknown CLAUDEX_INSTALL_MODE: %s\n' "$INSTALL_MODE" >&2
    exit 2
  fi

  if [[ ( -e "$CONFIG_HOME" || -L "$CONFIG_HOME" ) && ( ! -d "$CONFIG_HOME" || -L "$CONFIG_HOME" ) ]]; then
    printf 'Claudex requires a regular directory at %s. Nothing was changed.\n' "$CONFIG_HOME" >&2
    exit 1
  fi
  local proxy_path
  for proxy_path in "$CONFIG_FILE" "$TOKEN_FILE"; do
    if [[ ( -e "$proxy_path" || -L "$proxy_path" ) && ( ! -f "$proxy_path" || -L "$proxy_path" ) ]]; then
      printf 'Claudex requires a regular non-symlink file at %s. Nothing was changed.\n' "$proxy_path" >&2
      exit 1
    fi
  done
  if [[ -f "$CONFIG_FILE" && ! -f "$TOKEN_FILE" ]] || [[ ! -f "$CONFIG_FILE" && -f "$TOKEN_FILE" ]]; then
    printf 'Claudex setup is inconsistent: proxy config and token must either both exist or both be absent.\n' >&2
    printf 'Expected pair:\n  %s\n  %s\nNothing was changed; restore the missing file or move the remaining file aside.\n' "$CONFIG_FILE" "$TOKEN_FILE" >&2
    exit 1
  fi
  if [[ -d "$CONFIG_HOME" ]]; then
    python3 - "$CONFIG_HOME" <<'PY'
import os, stat, sys
mode = stat.S_IMODE(os.lstat(sys.argv[1]).st_mode)
if mode != 0o700:
    raise SystemExit(f"Claudex config directory must have mode 700 before installation (found {mode:o}). Nothing was changed. Run: chmod 700 {sys.argv[1]}")
PY
  fi
  if [[ -f "$CONFIG_FILE" && -f "$TOKEN_FILE" ]]; then
    local existing_token
    existing_token="$(<"$TOKEN_FILE")"
    if [[ -z "$existing_token" ]] || ! grep -Fq -- "$existing_token" "$CONFIG_FILE"; then
      printf 'Claudex setup is inconsistent: the existing proxy config does not contain the existing local token.\n' >&2
      printf 'Nothing was changed; restore a matching pair or move both files aside before reinstalling.\n' >&2
      exit 1
    fi
    python3 - "$CONFIG_FILE" "$TOKEN_FILE" <<'PY'
import os, stat, sys
for path in sys.argv[1:]:
    value = os.lstat(path)
    if not stat.S_ISREG(value.st_mode):
        raise SystemExit(f"Claudex requires a regular private file at {path}. Nothing was changed.")
    mode = stat.S_IMODE(value.st_mode)
    if mode != 0o600:
        raise SystemExit(f"Claudex requires mode 600 at {path} (found {mode:o}). Nothing was changed. Run: chmod 600 {path}")
PY
  fi
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  printf 'Homebrew is required to install CLIProxyAPI. Installing Homebrew...\n'
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

install_dependencies() {
  install_homebrew

  if ! command -v cliproxyapi >/dev/null 2>&1; then
    brew install cliproxyapi
  fi

  if ! command -v claude >/dev/null 2>&1; then
    printf 'Installing Claude Code with the official native installer...\n'
    curl -fsSL https://claude.ai/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
  fi

  if ! command -v codex >/dev/null 2>&1; then
    printf 'Installing the OpenAI Codex CLI...\n'
    if ! brew install --cask codex; then
      printf 'Homebrew Codex installation failed; falling back to npm.\n'
      command -v npm >/dev/null 2>&1 || brew install node
      npm install --global @openai/codex
    fi
  fi

  require_commands brew claude cliproxyapi codex curl
}

configure_claudex() {
  mkdir -p "$CONFIG_HOME" "$BIN_HOME" "$AGENT_HOME"
  chmod 700 "$CONFIG_HOME"

  if [[ ! -f "$TOKEN_FILE" ]]; then
    umask 077
    openssl rand -base64 32 >"$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"
  fi

  if [[ ! -f "$CONFIG_FILE" ]]; then
    local token
    token="$(<"$TOKEN_FILE")"
    sed "s|__CLAUDEX_LOCAL_TOKEN__|$token|g" \
      "$ROOT_DIR/config/cliproxyapi.yaml.example" >"$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
  fi

  install -m 755 "$ROOT_DIR/bin/claudex" "$BIN_HOME/claudex"
  install -m 755 "$ROOT_DIR/bin/claudex-review-receipt" "$BIN_HOME/claudex-review-receipt"
  install -m 755 "$ROOT_DIR/bin/claudex-usage-efficiency" "$BIN_HOME/claudex-usage-efficiency"
  install -m 644 "$ROOT_DIR/prompts/terra-routing.md" "$CONFIG_HOME/terra-routing.md"
  install -m 644 "$ROOT_DIR/agents/claudex-terra.md" "$AGENT_HOME/claudex-terra.md"
  install -m 644 "$ROOT_DIR/agents/claudex-implementer.md" "$AGENT_HOME/claudex-implementer.md"
  install -m 644 "$ROOT_DIR/agents/claudex-luna.md" "$AGENT_HOME/claudex-luna.md"
  install -m 644 "$ROOT_DIR/agents/claudex-sol.md" "$AGENT_HOME/claudex-sol.md"
  install -m 644 "$ROOT_DIR/agents/claudex-sol-review.md" "$AGENT_HOME/claudex-sol-review.md"
  install -m 644 "$ROOT_DIR/agents/claudex-frontend.md" "$AGENT_HOME/claudex-frontend.md"

  CLAUDEX_SYNC_INTERNAL=1 "$ROOT_DIR/scripts/sync-codex-orca.sh"
}

shell_rc_file() {
  if [[ "${SHELL:-}" == */zsh ]]; then
    printf '%s\n' "$HOME/.zshrc"
  elif [[ "${SHELL:-}" == */bash ]]; then
    printf '%s\n' "$HOME/.bashrc"
  else
    printf '%s\n' "$HOME/.profile"
  fi
}

managed_targets() {
  printf '%s\n' \
    "$BIN_HOME/claudex" \
    "$BIN_HOME/claudex-review-receipt" \
    "$BIN_HOME/claudex-usage-efficiency" \
    "$CONFIG_HOME/terra-routing.md" \
    "$AGENT_HOME/claudex-terra.md" \
    "$AGENT_HOME/claudex-implementer.md" \
    "$AGENT_HOME/claudex-luna.md" \
    "$AGENT_HOME/claudex-sol.md" \
    "$AGENT_HOME/claudex-sol-review.md" \
    "$AGENT_HOME/claudex-frontend.md"
  "$ROOT_DIR/scripts/sync-codex-orca.sh" --print-targets
  local rc_file
  rc_file="$(shell_rc_file)"
  if ! grep -Fq '# Claudex PATH' "$rc_file" 2>/dev/null; then
    printf '%s\n' "$rc_file"
  fi
}

begin_backup() {
  BACKUP_ID="$(managed_targets | python3 "$STATE_HELPER" --state-root "$STATE_ROOT" begin)"
  printf 'Claudex: created recoverable install backup %s.\n' "$BACKUP_ID"
}

finalize_backup() {
  python3 "$STATE_HELPER" --state-root "$STATE_ROOT" finalize "$BACKUP_ID"
  BACKUP_FINALIZED=1
}

handle_failure() {
  local status="$1"
  trap - ERR
  set +e
  if [[ -n "$BACKUP_ID" ]]; then
    if [[ "$BACKUP_FINALIZED" != "1" ]]; then
      python3 "$STATE_HELPER" --state-root "$STATE_ROOT" finalize "$BACKUP_ID"
      [[ $? -eq 0 ]] && BACKUP_FINALIZED=1
    fi
    if [[ "$BACKUP_FINALIZED" == "1" ]]; then
      printf '\nClaudex installation stopped after managed writes. A recoverable snapshot was finalized.\n' >&2
      printf 'Roll back with: ./scripts/uninstall.sh --restore-backup %s\n' "$BACKUP_ID" >&2
    else
      printf '\nClaudex installation stopped and its recovery snapshot could not be finalized.\n' >&2
      printf 'Preserve %s and inspect backup %s before retrying.\n' "$STATE_ROOT" "$BACKUP_ID" >&2
    fi
  fi
  exit "$status"
}

ensure_path() {
  case ":$PATH:" in
    *":$BIN_HOME:"*) return ;;
  esac

  local rc_file
  rc_file="$(shell_rc_file)"

  if ! grep -Fq '# Claudex PATH' "$rc_file" 2>/dev/null; then
    {
      printf '\n# Claudex PATH\n'
      printf 'export PATH="$HOME/.local/bin:$PATH"\n'
    } >>"$rc_file"
  fi

  export PATH="$BIN_HOME:$PATH"
  printf 'Added %s to PATH in %s.\n' "$BIN_HOME" "$rc_file"
}

login_codex() {
  if [[ "$SKIP_LOGIN" == "1" ]]; then
    printf 'Skipped Codex OAuth login. Run:\n  cliproxyapi -config %q -codex-login\n' "$CONFIG_FILE"
    return
  fi

  if compgen -G "$HOME/.cli-proxy-api/codex-*.json" >/dev/null; then
    printf 'An existing Codex OAuth credential was found; skipping login.\n'
    return
  fi

  printf '\nSign in to the Codex account that Claudex should use.\n'
  cliproxyapi -config "$CONFIG_FILE" -codex-login
}

main() {
  preflight
  if [[ "$INSTALL_MODE" == "full" ]]; then
    install_dependencies
  fi
  begin_backup
  trap 'handle_failure $?' ERR
  configure_claudex
  ensure_path
  finalize_backup
  "$ROOT_DIR/scripts/verify-install.sh"
  login_codex

  printf '\nClaudex files installed and locally verified.\n'
  printf 'Backup ID: %s\n' "$BACKUP_ID"
  printf 'Default model: gpt-5.5 (low effort)\n'
  printf 'Default effort: low\n'
  printf 'Installed agents: GPT-5.5 coordinator (Terra alias), GPT-5.6 Sol low Implementer, Luna data/research, Frontend implementer, Sol advisory, Sol Review gate\n'
  printf 'Start it with: claudex\n'
  if [[ "$SKIP_LOGIN" == "1" ]]; then
    printf 'OAuth was skipped; Claudex is not yet verified end to end.\n'
  else
    printf 'Complete the authenticated smoke test with:\n  claudex --print "Reply with exactly: OK"\n'
  fi
}

main
