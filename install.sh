#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/claudex"
BIN_HOME="$HOME/.local/bin"
CONFIG_FILE="$CONFIG_HOME/cliproxyapi.yaml"
TOKEN_FILE="$CONFIG_HOME/token"
SKIP_LOGIN=0

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

  command -v curl >/dev/null 2>&1 || {
    printf 'curl is required but was not found.\n' >&2
    exit 1
  }
}

configure_claudex() {
  mkdir -p "$CONFIG_HOME" "$BIN_HOME"
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
  install_dependencies
  configure_claudex
  ensure_path
  login_codex

  printf '\nClaudex installed successfully.\n'
  printf 'Default model: gpt-5.6-terra\n'
  printf 'Default effort: high\n'
  printf 'Start it with: claudex\n'
  printf 'Verify dependencies with: claude --version && cliproxyapi --help\n'
}

main
