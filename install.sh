#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/claudex"
BIN_HOME="$HOME/.local/bin"
AGENT_HOME="$HOME/.claude/agents"
CONFIG_FILE="$CONFIG_HOME/cliproxyapi.yaml"
TOKEN_FILE="$CONFIG_HOME/token"
SKIP_LOGIN=0
INSTALL_MODE="${CLAUDEX_INSTALL_MODE:-full}"

if [[ "${1:-}" == "--skip-login" ]]; then
  SKIP_LOGIN=1
elif [[ -n "${1:-}" ]]; then
  printf 'Usage: %s [--skip-login]\n' "$0" >&2
  exit 2
fi

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

  command -v curl >/dev/null 2>&1 || {
    printf 'curl is required but was not found.\n' >&2
    exit 1
  }
}

configure_claudex() {
  mkdir -p "$CONFIG_HOME" "$BIN_HOME" "$AGENT_HOME"
  chmod 700 "$CONFIG_HOME"

  if [[ ! -f "$TOKEN_FILE" ]]; then
    umask 077
    openssl rand -base64 32 >"$TOKEN_FILE"
  fi
  chmod 600 "$TOKEN_FILE"

  if [[ ! -f "$CONFIG_FILE" ]]; then
    local token
    token="$(<"$TOKEN_FILE")"
    sed "s|__CLAUDEX_LOCAL_TOKEN__|$token|g" \
      "$ROOT_DIR/config/cliproxyapi.yaml.example" >"$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
  fi

  install -m 755 "$ROOT_DIR/bin/claudex" "$BIN_HOME/claudex"
  install -m 755 "$ROOT_DIR/bin/claudex-review-receipt" "$BIN_HOME/claudex-review-receipt"
  install -m 644 "$ROOT_DIR/prompts/terra-routing.md" "$CONFIG_HOME/terra-routing.md"
  install -m 644 "$ROOT_DIR/agents/claudex-terra.md" "$AGENT_HOME/claudex-terra.md"
  install -m 644 "$ROOT_DIR/agents/claudex-luna.md" "$AGENT_HOME/claudex-luna.md"
  install -m 644 "$ROOT_DIR/agents/claudex-sol.md" "$AGENT_HOME/claudex-sol.md"
  install -m 644 "$ROOT_DIR/agents/claudex-sol-review.md" "$AGENT_HOME/claudex-sol-review.md"
  install -m 644 "$ROOT_DIR/agents/claudex-frontend.md" "$AGENT_HOME/claudex-frontend.md"

  "$ROOT_DIR/scripts/sync-codex-orca.sh"
}

ensure_path() {
  case ":$PATH:" in
    *":$BIN_HOME:"*) return ;;
  esac

  local rc_file="$HOME/.profile"
  if [[ "${SHELL:-}" == */zsh ]]; then
    rc_file="$HOME/.zshrc"
  elif [[ "${SHELL:-}" == */bash ]]; then
    rc_file="$HOME/.bashrc"
  fi

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
  if [[ "$INSTALL_MODE" == "full" ]]; then
    install_dependencies
  elif [[ "$INSTALL_MODE" != "configure-only" ]]; then
    printf 'Unknown CLAUDEX_INSTALL_MODE: %s\n' "$INSTALL_MODE" >&2
    exit 2
  fi
  configure_claudex
  ensure_path
  login_codex

  printf '\nClaudex installed successfully.\n'
  printf 'Default model: gpt-5.5 (medium effort)\n'
  printf 'Default effort: medium\n'
  printf 'Installed agents: GPT-5.5 coordinator (Terra alias), Luna data/research, Frontend implementer, Sol advisory, Sol Review gate\n'
  printf 'Start it with: claudex\n'
  printf 'Verify dependencies with: claude --version && codex --version && cliproxyapi --help\n'
}

main
