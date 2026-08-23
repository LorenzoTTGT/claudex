# Claudex

Claudex launches **Claude Code** through a local [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) bridge backed by Codex OAuth.

Defaults:

- Coordinator: `gpt-5.5` / medium — permanent coordinator and implementer (`terra` remains a compatibility alias)
- Luna: `gpt-5.6-luna` / high — read-only research and data-operations worker
- Frontend: `gpt-5.5` / high — bounded GUI/frontend implementation and code-generation worker
- Sol advisory: `gpt-5.6-sol` / medium — read-only architecture advice and early risk triage
- Sol Review: `gpt-5.6-sol` / medium — read-only consequential-change and final-review gate
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
8. Installs the five Claudex agent definitions to `~/.claude/agents`.
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

`claudex` keeps the native Claude Code main agent on GPT-5.5/medium. It appends the source-controlled routing policy from `prompts/terra-routing.md` rather than replacing Claude Code’s main system prompt, so native planning and built-in delegation remain available. Terra-named files and commands remain compatibility aliases. The policy delegates only bounded side work:

```bash
# Read-only repository/data investigation; returns compressed findings.
claudex luna "Inventory the request-validation paths and tests."

# Read-only architecture analysis.
claudex sol "Compare the migration strategies for this schema change."

# Bounded frontend implementation using GPT-5.5/high.
claudex frontend "Implement the requested responsive settings panel and its frontend tests."

# Read-only review of the current staged diff. A valid PASS creates a receipt.
claudex sol-review
```

Luna is for broad, rule-based work: inventories, data-quality checks, naming consistency, log grouping, and parsing/transform plans. It must not edit files or change state. Use deterministic scripts for known bulk transformations.

Frontend is a fixed `gpt-5.5` / high-effort implementer for bounded UI components, styling, accessibility, responsive behavior, frontend tests, and directly necessary frontend-local assets. It may not change backend logic, schemas, authentication, public APIs, deployment, or unrelated shared infrastructure; when ownership is unclear, it returns the boundary to the coordinator. The coordinator retains task decomposition, verification synthesis, final integration, and completion reporting. Frontend implementation and tests never replace a required Sol Review or review receipt.

Use medium-effort Sol for bounded architecture alternatives, early risk triage, implementation-plan feedback, consequential decisions, and substantial or sensitive diff review. Sol Review returns `PASS`, `CHANGES_REQUIRED`, or `BLOCKED`; it recommends and the GPT-5.5 coordinator implements. For consequential work, the coordinator must get an independent medium-effort Sol Review before approving the plan or starting implementation, and another before treating the work as complete or merge-ready. Keep coordinator ↔ Sol Review correction loops to two; surface disagreements after that.

Claudex prefers root-cause fixes over workaround layers, verifies actual runtime behavior instead of trusting configuration or agent claims, and states intended behavior before Sol reviews a diff so findings stay tied to the requested outcome rather than generic style preferences.

For difficult bugs and performance regressions, Claudex first seeks a runnable feedback loop for the exact symptom. Tests favor stable public behavior and independently derived expected results. Sol uses a single review pass with findings separated into `Behavior/Spec` and `Repository Standards`; standards must come from the repository rather than generic preference.

Claudex applies YAGNI, avoids speculative compatibility and fallback layers, uses focused tests for meaningful current behavior, and matches planning, delegation, and verification ceremony to task size. Review feedback cannot expand the original goal. Human-facing summaries lead with the problem and outcome rather than an implementation inventory. Persistent global guidance requires repeated observed failure, and skill descriptions stay focused on trigger conditions.

Luna, Frontend, Sol advisory, and Sol Review are ordinary Claude Code custom agents with fixed `high`, `high`, `medium`, and `medium` effort respectively. Frontend's agent, model, and effort are intentionally fixed and cannot be overridden from its command. Existing users must rerun the installer after updating Claudex, then restart Claude Code or use `/agents` to reload the definitions.

For a non-trivial request, Terra keeps an in-session checklist and carries available investigation, implementation, validation, and integration steps through to completion instead of reporting an intention to do the next step later. A request for planning, explanation, read-only analysis, or a partial checkpoint limits the requested scope; Terra still completes that requested analysis or checkpoint with the available evidence. The contract never bypasses approval or authorization boundaries.

## Session supervision

The same-session completion contract is agent work discipline, not lifecycle automation: it adds no hooks, polling, process watching, task/session persistence, automatic resume/restart, session selection, or synthetic continuation. Claudex does not currently autonomously monitor, restart, select, or resume Claude Code sessions. User-supplied Claude Code arguments, including `claudex --resume`, are transparently passed through to the native CLI and are outside this supervisor boundary. The [Claude Code session supervision assessment](./docs/claude-code-supervisor.md) documents the official hook, local-session, headless, and Agent SDK interfaces that may support a later reviewed integration. In particular, a quiet session, a hook event, or `claude agents --json` output is not proof that a thread has stopped, and no automatic continuation is implemented.

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
CLAUDEX_MODEL=gpt-5.6-sol CLAUDEX_EFFORT=high claudex
```

Supported variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `CLAUDEX_MODEL` | `gpt-5.5` | Main model |
| `CLAUDEX_EFFORT` | `medium` | Main-session reasoning effort (`xhigh` is rejected) |
| `CLAUDEX_OPUS_MODEL` | `gpt-5.6-sol` | Custom Opus route shown in `/model` |
| `CLAUDEX_HAIKU_MODEL` | `gpt-5.6-luna` | Lightweight model route |
| `CLAUDEX_LUNA_MODEL` | `gpt-5.6-luna` | Luna subagent model |
| `CLAUDEX_SOL_MODEL` | `gpt-5.6-sol` | Sol subagent model |
| `CLAUDEX_AUTOCOMPACT` | `220k` | Claude Code compaction threshold (`auto` or a supported token value) |
| `CLAUDEX_TELEMETRY` | `0` | Opt-in local, content-free launcher telemetry |
| `CLAUDEX_TERRA_PROMPT_FILE` | `~/.config/claudex/terra-routing.md` | Appended native-agent routing policy |
| `CLAUDEX_BASE_URL` | `http://127.0.0.1:8317` | Local proxy URL |
| `CLAUDEX_PROXY_CONFIG` | `~/.config/claudex/cliproxyapi.yaml` | Proxy configuration |
| `CLAUDEX_TOKEN_FILE` | `~/.config/claudex/token` | Local proxy token |

`CLAUDEX_EFFORT` and a compatibility `terra` CLI `--effort` argument control only the main GPT-5.5 session. Luna, Frontend, Sol advisory, and Sol Review have fixed role efforts. Frontend also fixes its agent and model to `claudex-frontend` and `gpt-5.5`; its command rejects agent, model, and effort overrides. `xhigh` is unsupported and rejected before Claudex starts or probes the proxy.

Claudex bypasses Claude Code permission prompts by default. Re-enable them for one session:

```bash
CLAUDEX_SKIP_PERMISSIONS=0 claudex
```

`CLAUDEX_SKIP_PERMISSIONS=1` weakens Claude Code permission enforcement. Use `CLAUDEX_SKIP_PERMISSIONS=0` with Luna or Sol if you need their read-only guarantees enforced by the client; their definitions also prohibit mutations in their instructions.

### Local launcher telemetry

Set `CLAUDEX_TELEMETRY=1` to write opt-in, local-only JSONL records to `${XDG_STATE_HOME:-~/.local/state}/claudex/telemetry/events.jsonl`. The directory is private, telemetry is capped at 5 MiB, and deleting that directory erases all telemetry. Nothing is sent over the network.

Records contain only allowlisted launcher observations: a random invocation identifier, launcher telemetry revision, selected route/mode/effort/autocompact category, proxy-start/readiness observations, direct Claude child elapsed time and exit code, and Sol-review verdict/receipt status. They never contain prompts, arguments, transcripts, paths, repositories, credentials, provider payloads, stdout/stderr, process IDs, Claude session IDs, or raw environment values.

This is not session supervision. A child exit code or proxy readiness does not prove a Claude Code session completed, and telemetry does not observe token usage, provider retries, native delegation, actual compaction, cost, or any session lifecycle state. It never retries, resumes, restarts, or steers a session. Telemetry write failures are ignored so they cannot stop Claude Code from launching.

For a comparison, use separate runs of the same externally managed task, warm up first, and repeat each configuration. Group records by their fixed route, effort, autocompact, and launcher revision tuple; change one routing variable at a time. Keep benchmark prompts, task identity, outputs, and quality assessment outside telemetry. A future token/event integration needs separate review and must use an upstream structured, content-free, invocation-correlated source.

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
