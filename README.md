# Claudex

Claudex launches **Claude Code** through a local [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) bridge backed by Codex OAuth.

Defaults:

- Model: `gpt-5.6-terra`
- Effort: `high`
- Lightweight/default Haiku route: `gpt-5.6-luna`
- Proxy: localhost only (`127.0.0.1:8317`)
- Claude Code permission prompts: enabled

## Install

### macOS or Linux

```bash
git clone https://github.com/LorenzoTTGT/claudex.git
cd claudex
./install.sh
```

The installer:

1. Installs Homebrew if it is unavailable.
2. Installs CLIProxyAPI using Homebrew.
3. Installs Claude Code using Anthropic's official native installer when it is not found.
4. Installs the OpenAI Codex CLI using Homebrew, with an npm fallback, when it is not found.
5. Generates a unique local proxy token.
6. Installs the `claudex` launcher to `~/.local/bin`.
7. Starts the Codex OAuth login when credentials are not already present.

Restart your shell after installation if `claudex` is not immediately found.

## Run

```bash
claudex
```

Arguments are passed directly to Claude Code:

```bash
claudex --resume
claudex --print "Reply with exactly: OK"
```

CLIProxyAPI starts automatically on the first launch and remains local to the computer.

## Configuration

Override defaults for one invocation:

```bash
CLAUDEX_MODEL=gpt-5.6-sol CLAUDEX_EFFORT=xhigh claudex
```

Supported variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `CLAUDEX_MODEL` | `gpt-5.6-terra` | Main model |
| `CLAUDEX_EFFORT` | `high` | Reasoning effort |
| `CLAUDEX_HAIKU_MODEL` | `gpt-5.6-luna` | Lightweight model route |
| `CLAUDEX_BASE_URL` | `http://127.0.0.1:8317` | Local proxy URL |
| `CLAUDEX_PROXY_CONFIG` | `~/.config/claudex/cliproxyapi.yaml` | Proxy configuration |
| `CLAUDEX_TOKEN_FILE` | `~/.config/claudex/token` | Local proxy token |

To intentionally bypass Claude Code permission prompts for a single session:

```bash
CLAUDEX_SKIP_PERMISSIONS=1 claudex
```

This is unsafe and is never enabled by default.

## Re-authenticate

```bash
cliproxyapi -config ~/.config/claudex/cliproxyapi.yaml -codex-login
```

OAuth credentials are stored by CLIProxyAPI under `~/.cli-proxy-api`. They are not part of this repository.

## Update

```bash
cd claudex
git pull
./install.sh --skip-login
```

Update dependencies separately when needed:

```bash
brew upgrade cliproxyapi
brew upgrade --cask codex
claude update
```

## Security

- No API keys, OAuth credentials, local tokens, transcripts, or user settings are committed.
- The generated proxy binds only to `127.0.0.1`.
- Treat private repositories as if they could eventually become public.
- Never commit `~/.cli-proxy-api`, `~/.config/claudex/token`, or generated proxy configuration.

## Requirements

- macOS or Linux
- Internet access during installation
- A Codex account accepted by CLIProxyAPI's OAuth flow
- Git

Claude Code documentation: <https://code.claude.com/docs/en/setup>
