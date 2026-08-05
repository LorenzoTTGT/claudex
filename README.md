# Claudex

Claudex launches **Claude Code** through a local [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) bridge backed by Codex OAuth.

Defaults:

- Terra: `gpt-5.6-terra` / high — permanent coordinator and implementer
- Luna: `gpt-5.6-luna` — read-only research and data-operations worker
- Sol: `gpt-5.6-sol` — read-only architecture and substantial-change reviewer
- Proxy: localhost only (`127.0.0.1:8317`)
- Claude Code permission prompts: bypassed by default

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
7. Installs the source-controlled Terra routing prompt to `~/.config/claudex/terra-routing.md`.
8. Installs the three Claudex subagent definitions to `~/.claude/agents`.
9. Starts the Codex OAuth login when credentials are not already present.

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

## Agent workflow

`claudex` keeps the native Claude Code main agent on Terra. It appends the source-controlled routing policy from `prompts/terra-routing.md` rather than replacing Claude Code’s main system prompt, so native planning and built-in delegation remain available. The policy delegates only bounded side work:

```bash
# Read-only repository/data investigation; returns compressed findings.
claudex luna "Inventory the request-validation paths and tests."

# Read-only architecture analysis.
claudex sol "Compare the migration strategies for this schema change."

# Read-only review of the current staged diff. A valid PASS creates a receipt.
claudex sol-review
```

Luna is for broad, rule-based work: inventories, data-quality checks, naming consistency, log grouping, and parsing/transform plans. It must not edit files or change state. Use deterministic scripts for known bulk transformations.

Sol returns `PASS`, `CHANGES_REQUIRED`, or `BLOCKED`; it recommends and Terra implements. Use Sol for architecture decisions and substantial or sensitive changes. For consequential work, Terra must get an independent Sol review before approving the plan or starting implementation, and another independent Sol review before treating the work as complete or merge-ready. A generic planning agent is not a substitute. Keep Terra ↔ Sol correction loops to two; surface disagreements after that.

Luna and Sol are ordinary Claude Code custom agents with explicit `high` effort. Restart Claude Code after installing/updating Claudex, or use `/agents` to reload them.

## Review receipt gate

Install the gate in a repository when you want sensitive/substantial commits to require a Sol review:

```bash
cd your-repository
claudex install-hook
```

The hook never calls a model. It deterministically requires a matching `PASS` receipt only when the staged diff is sensitive (auth, permissions, payments, migrations, deployment, dependency manifests) or substantial (20+ files, 800+ changed lines, or three+ top-level areas).

For those substantial or sensitive changes, `claudex sol-review` also requires deterministic verification-command evidence for the exact staged tree. Sol reviews an isolated checkout of that tree; the commands and their policy file also come from the staged tree and run in a separate detached worktree. Unstaged or untracked files therefore cannot influence either review or verification. Configure one command per line in `.claudex/verify-commands` and commit that policy with the project:

```bash
mkdir -p .claudex
cat > .claudex/verify-commands <<'EOF'
npm run lint
npm test
EOF
git add .claudex/verify-commands
```

```bash
git add -A
claudex sol-review    # creates a receipt bound to this exact staged tree, with Sol PASS + verification evidence
git commit -m "..."  # allowed only if that receipt says PASS and the verification commands passed
```

Any staged change changes the tree hash and makes the receipt stale. Receipts are stored locally in `${XDG_STATE_HOME:-~/.local/state}/claudex/reviews`; they are not committed. Check a gate manually with `claudex review-gate`.

This is a local workflow guardrail, not a security boundary against someone who controls the repository and machine: Git hooks can be bypassed or modified. Its purpose is to prevent accidental commits without matching review and verification evidence.

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
| `CLAUDEX_OPUS_MODEL` | `gpt-5.6-sol` | Custom Opus route shown in `/model` |
| `CLAUDEX_HAIKU_MODEL` | `gpt-5.6-luna` | Lightweight model route |
| `CLAUDEX_LUNA_MODEL` | `gpt-5.6-luna` | Luna subagent model |
| `CLAUDEX_SOL_MODEL` | `gpt-5.6-sol` | Sol subagent model |
| `CLAUDEX_AUTOCOMPACT` | `220k` | Claude Code compaction threshold (`auto` or a supported token value) |
| `CLAUDEX_TERRA_PROMPT_FILE` | `~/.config/claudex/terra-routing.md` | Appended native-agent routing policy |
| `CLAUDEX_BASE_URL` | `http://127.0.0.1:8317` | Local proxy URL |
| `CLAUDEX_PROXY_CONFIG` | `~/.config/claudex/cliproxyapi.yaml` | Proxy configuration |
| `CLAUDEX_TOKEN_FILE` | `~/.config/claudex/token` | Local proxy token |

Claudex bypasses Claude Code permission prompts by default. Re-enable them for one session:

```bash
CLAUDEX_SKIP_PERMISSIONS=0 claudex
```

`CLAUDEX_SKIP_PERMISSIONS=1` weakens Claude Code permission enforcement. Use `CLAUDEX_SKIP_PERMISSIONS=0` with Luna or Sol if you need their read-only guarantees enforced by the client; their definitions also prohibit mutations in their instructions.

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

That reinstall step refreshes the installed Terra routing prompt and agent definitions from the repository sources.

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
