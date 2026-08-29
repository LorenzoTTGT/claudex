# Claudex

Claudex launches **Claude Code** through a local [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) bridge backed by Codex OAuth.

Defaults:

- Coordinator: `gpt-5.6-sol` / low — permanent coordinator, small-edit executor, and final integrator (`terra` remains a compatibility alias)
- Implementer: `gpt-5.6-sol` / low — bounded substantial non-frontend implementation
- Luna: `gpt-5.6-luna` / high — read-only research and data-operations worker
- Frontend: `gpt-5.6-terra` / high — bounded GUI/frontend implementation and code-generation worker
- Sol advisory: `gpt-5.6-sol` / medium — read-only architecture advice and early risk triage
- Sol Review: `gpt-5.6-sol` / medium — read-only consequential-change and final-review gate
- Proxy: localhost only (`127.0.0.1:8317`)
- Claude Code permission prompts: bypassed by default

## Requirements

- A Homebrew-supported macOS or Linux system
- Internet access during dependency installation and OAuth
- Git, Bash, `curl`, OpenSSL, Python 3, and standard POSIX file utilities
- A Codex account accepted by CLIProxyAPI's OAuth flow
- Permission to install packages and update user-level configuration

The installer adds Homebrew when it is unavailable, then uses it to install CLIProxyAPI and, when needed, Codex. It uses Anthropic's official native installer for Claude Code. Review those third-party installers and obtain the computer owner's authorization before running them.

## Install

### macOS or Linux

```bash
git clone https://github.com/LorenzoTTGT/claudex.git
cd claudex
./install.sh
```

The installer:

1. Validates the platform, prerequisites, and proxy config/token consistency before changing files.
2. Installs missing Homebrew, CLIProxyAPI, Claude Code, and Codex dependencies.
3. Creates a private, timestamped recovery snapshot of every managed path it will change.
4. Generates a unique local proxy token and config on a fresh installation. Existing matching config/token files are preserved.
5. Installs the launcher and utilities to `~/.local/bin`, routing policy to `~/.config/claudex`, and Claude agents to `~/.claude/agents`.
6. Installs the global Codex policy, agents, skills, and three-thread/one-level subagent limits under `~/.codex`.
7. Updates an existing Orca Codex runtime when detected. It does not create an absent Orca runtime unless explicitly enabled.
8. Runs deterministic local verification, then starts Codex OAuth when credentials are not already present.

### Safety and mutation scope

The installer manages these user-level targets:

| Target | Behavior |
| --- | --- |
| `~/.local/bin/claudex*` | Replaced with repository launchers/utilities |
| `~/.config/claudex/terra-routing.md` | Replaced with the repository routing prompt |
| `~/.claude/agents/claudex-*.md` | Replaced with the six repository agent definitions |
| `~/.codex/AGENTS.md` | Replaced with the Claudex global Codex policy |
| `~/.codex/agents/<managed files>` | Managed files are replaced; unknown sibling files are preserved |
| `~/.codex/skills/<managed files>` | Managed files are replaced; unknown sibling files are preserved |
| `~/.codex/config.toml` | The `[agents]` section is updated to `max_threads = 3` and `max_depth = 1` |
| Shell startup file | An exact `# Claudex PATH` block is appended only when needed |
| Existing Orca runtime | Receives the equivalent Codex policy, agents, skills, and agent limits |

Before these writes, originals and per-run states are stored under `${XDG_STATE_HOME:-~/.local/state}/claudex/install-backups` with private permissions. Reinstalls preserve the first pre-Claudex state and add a new rollback point. OAuth credentials under `~/.cli-proxy-api` are never copied into backups.

Set `CLAUDEX_SYNC_ORCA_CODEX=1` to explicitly create/sync the configured Orca runtime, or `CLAUDEX_SYNC_ORCA_CODEX=0` to disable Orca sync. Setting `ORCA_CODEX_HOME` explicitly also authorizes that target.

### Agent installation contract

An agent installing Claudex should:

1. Read this mutation list and confirm that package installation, OAuth, and user-global configuration changes are authorized.
2. Inspect pre-existing files in the managed targets when preserving local customization matters.
3. Run `./install.sh` without suppressing its output.
4. Hand control to the human for the browser/device OAuth interaction. Never request, expose, or copy credentials.
5. Require the installer's local-verification success message.
6. Run the authenticated smoke test below after OAuth. If login was skipped, do not claim Claudex works end to end.
7. Explain the human quick start and permission behavior below.

Restart your shell after installation if `claudex` is not immediately found.

If Claude Code was already open, restart it or run `/agents` so it reloads the new custom agents.

## Verify installation

The installer runs the non-networked file/configuration check automatically. Run it again from the clone at any time:

```bash
./scripts/verify-install.sh
```

That check verifies installed files, commands, token/config consistency, private permissions, and Codex agent limits. It does not prove that OAuth is valid or that the model is reachable.

Repository regression checks for launcher, installer, review-gate, telemetry, Codex/Orca sync, routing-policy, and documentation invariants live in `tests/run.sh`; they are for development and release validation, not the normal install smoke test.

After OAuth, run the explicit end-to-end smoke test:

```bash
claudex --print "Reply with exactly: OK"
```

Expected output is `OK`. This starts the local proxy and makes a model request. Do not report an operational installation until this succeeds.

## Human quick start

Open a terminal in the project you want to work on and run:

```bash
cd path/to/your-project
claudex
```

Then describe the task normally. The coordinator handles implementation and automatically routes research to Luna, frontend work to Frontend, and planning or architecture decisions to Sol. Humans normally do not need to select an agent manually.

Claudex bypasses Claude Code permission prompts by default. For normal permission prompts, start it with:

```bash
CLAUDEX_SKIP_PERMISSIONS=0 claudex
```

Arguments are passed directly to Claude Code:

```bash
claudex --resume
claudex --print "Reply with exactly: OK"
```

Direct role commands are optional and useful when the human wants to force a bounded task; the next section lists them.

## Agent workflow

`claudex` keeps the native Claude Code main agent on GPT-5.6 Sol/low by default. It appends the source-controlled routing policy from `prompts/terra-routing.md` rather than replacing Claude Code’s main system prompt, so native planning and built-in delegation remain available. Terra-named files and commands remain compatibility aliases. Set `CLAUDEX_EFFORT=medium` or pass `--effort medium` when one stronger root should own cross-cutting or iterative work. The policy delegates only bounded work:

```bash
# Read-only repository/data investigation; returns compressed findings.
claudex luna "Inventory the request-validation paths and tests."

# Read-only architecture analysis.
claudex sol "Compare the migration strategies for this schema change."

# Bounded frontend implementation using Terra/high.
claudex frontend "Implement the requested responsive settings panel and its frontend tests."

# Read-only review of the current staged diff. A valid PASS creates a receipt.
claudex sol-review
```

### Installed Claude Code subagents

The installer refreshes these source-controlled Claude Code custom agents into `~/.claude/agents`:

| Agent | Model / effort | Permission mode | Role |
| --- | --- | --- | --- |
| `claudex-terra` | `gpt-5.6-sol` / low | default | Default coordinator, small-edit executor, verification synthesizer, and final integrator; `terra` remains a compatibility alias for the main `claudex` route. |
| `claudex-implementer` | `gpt-5.6-sol` / low | default | Substantial, bounded non-frontend implementation after behavior, acceptance criteria, exclusive ownership, relevant Sol decisions when applicable, and checks are explicit. |
| `claudex-luna` | `gpt-5.6-luna` / high | plan | Read-only research and data-analysis specialist for broad inventories, maps, structured-data inspection, validation anomalies, naming/stale-reference audits, log/test/diff classification, broad diff-risk maps, and concise evidence summaries. |
| `claudex-sol` | `gpt-5.6-sol` / medium | plan | Mandatory read-only advisory for implementation plans and architecture choices, plus bounded alternatives and early risk triage. |
| `claudex-sol-review` | `gpt-5.6-sol` / medium | plan | Read-only consequential-change and final-review gate returning `PASS`, `CHANGES_REQUIRED`, or `BLOCKED`. |
| `claudex-frontend` | `gpt-5.6-terra` / high | default | Bounded frontend implementer for UI components, styling, accessibility, responsive behavior, visual regressions, frontend tests, and frontend-local assets. |

Luna is for broad, rule-based work whenever breadth is the cost: inventories, call-site maps, data-quality checks, naming and stale-reference audits, broad diff-risk maps, log/test failure grouping, and parsing/transform plans. Use Luna to compress evidence before Sol, implementation, or Sol Review when the coordinator would otherwise search many files. It must not edit files, decide architecture, approve reviews, or change state. Use deterministic scripts for known bulk transformations.

Implementer is a GPT-5.6 Sol / low-effort role for substantial bounded non-frontend coding, coupled components, reproducible difficult bugs, or one failed coordinator attempt. Ambiguity and architecture choices must be resolved before delegation. The coordinator supplies intended behavior, acceptance criteria, owned and excluded files or change areas, relevant Sol decisions when applicable, and required checks; only one writer may own an area at a time. Implementer cannot delegate, broaden scope, commit, push, deploy, delete, mutate external systems, or replace coordinator diff inspection, independent verification, final integration, and completion reporting. Consequential implementation requires the existing pre-implementation Sol and risk-based Sol Review gates and remains subject to final Sol Review; routine low-risk implementation by this Sol-backed implementer does not itself create a Sol Review requirement.

The installer also syncs Claudex-aligned Codex/Orca subagents from `codex/agents/`: `claudex-luna`, `claudex-sol`, `claudex-sol-review`, and `claudex-frontend` mirror the primary Claudex roles; `default`, `worker`, `worker_high`, `explorer`, `clerical`, and `architect` are compatibility/fallback roles for existing Codex workflows. `codex/AGENTS.md` is the source of truth for their routing policy.

Frontend is a fixed `gpt-5.6-terra` / high-effort implementer for bounded UI components, styling, accessibility, responsive behavior, frontend tests, and directly necessary frontend-local assets. It may not change backend logic, schemas, authentication, public APIs, deployment, or unrelated shared infrastructure; when ownership is unclear, it returns the boundary to the coordinator. The coordinator retains task decomposition, verification synthesis, final integration, and completion reporting. Frontend implementation and tests never replace a required Sol Review or review receipt.

Use medium-effort Sol for scoped feedback whenever the coordinator creates, presents, approves, or reviews a non-trivial implementation plan or makes, presents, approves, or reviews an architecture choice. Reserve high-effort Sol passes for major planning, security-sensitive architecture, migrations, public contracts, release blockers, or unresolved disagreement. An operative user mention of `plan`, `planning`, `architecture`, or `architectural` is a direct trigger unless clearly negated. An architecture choice means a decision among credible structural, contract, data-flow, storage, or dependency alternatives, not a routine mechanical implementation choice. One Sol invocation may cover a plan and its architecture choices; materially revising the plan or introducing a new architecture choice requires another invocation. A trivial direct edit needing neither does not trigger Sol, and work should not be artificially planned just to trigger delegation.

Sol Review returns `PASS`, `CHANGES_REQUIRED`, or `BLOCKED`; it recommends and the GPT-5.6 Sol coordinator implements. Trigger Sol Review by consequence, sensitivity, substantiality, release criticality, or experimental/non-primary implementation risk rather than model identity alone. For consequential work, the Sol advisory and GPT-5.6 Sol-backed implementation are additional to and never replace the independent medium-effort Sol Review required before approving the plan or starting implementation, or the second review required before treating the work as complete or merge-ready. Tiny, bounded, reversible, non-sensitive edits and routine Sol-backed implementation with clear validation do not need Sol Review. For broad diffs that may or may not need formal review, prefer a cheap Luna risk map first. Keep coordinator ↔ Sol Review correction loops to two; surface disagreements after that.

Claudex prefers root-cause fixes over workaround layers, verifies actual runtime behavior instead of trusting configuration or agent claims, and states intended behavior before Sol reviews a diff so findings stay tied to the requested outcome rather than generic style preferences.

For difficult bugs and performance regressions, Claudex first seeks a runnable feedback loop for the exact symptom. Tests favor stable public behavior and independently derived expected results. Sol uses a single review pass with findings separated into `Behavior/Spec` and `Repository Standards`; standards must come from the repository rather than generic preference.

Claudex applies YAGNI, avoids speculative compatibility and fallback layers, uses focused tests for meaningful current behavior, and matches planning, delegation, and verification ceremony to task size. Review feedback cannot expand the original goal. Human-facing summaries lead with the problem and outcome rather than an implementation inventory. Persistent global guidance requires repeated observed failure, and skill descriptions stay focused on trigger conditions.

Implementer, Luna, Frontend, Sol advisory, and Sol Review are ordinary Claude Code custom agents with fixed `low`, `high`, `high`, `medium`, and `medium` effort respectively. Implementer uses GPT-5.6 Sol at low effort for bounded non-frontend implementation; Sol advisory and Sol Review remain read-only roles. Frontend's agent, model, and effort are intentionally fixed and cannot be overridden from its command. Existing users must rerun the installer after updating Claudex, then restart Claude Code or use `/agents` to reload the definitions.

### Context and cost discipline

Claudex keeps the always-appended coordinator policy compact and uses isolated subagents when verbose tests, logs, documentation, or broad research would otherwise fill the main context. Use `/clear` between unrelated tasks and a focused `/compact`, such as `/compact focus on the current API change and its tests`, at a natural phase boundary when a long session needs summarizing. These are deliberate user/session actions; Claudex does not clear or compact automatically beyond Claude Code's configured auto-compaction.

Claudex intentionally does not enable agent teams, nested delegation, automatic classifier agents, persistent task memory, automatic retries, or worktrees by default. They add context, coordination, or lifecycle complexity and are reserved for explicit future designs backed by measured need. Keep optional Claude Code plugins and MCP servers disabled or uninstalled when they are not used; they are user-level Claude Code configuration rather than Claudex-managed installation targets.

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
| `CLAUDEX_MODEL` | `gpt-5.6-sol` | Main model |
| `CLAUDEX_EFFORT` | `low` | Main-session reasoning effort (`xhigh` is rejected); use `medium` when one stronger root should own cross-cutting or iterative work |
| `CLAUDEX_OPUS_MODEL` | `gpt-5.6-sol` | Custom Opus route shown in `/model` |
| `CLAUDEX_SONNET_MODEL` | falls back to `CLAUDEX_MODEL` | Custom Sonnet route shown in `/model` |
| `CLAUDEX_HAIKU_MODEL` | `gpt-5.6-luna` | Lightweight model route |
| `CLAUDEX_LUNA_MODEL` | `gpt-5.6-luna` | Luna subagent model |
| `CLAUDEX_SOL_MODEL` | `gpt-5.6-sol` | Sol subagent model |
| `CLAUDEX_AUTOCOMPACT` | `220k` | Claude Code compaction threshold (`auto` or a supported token value) |
| `CLAUDEX_TELEMETRY` | `0` | Opt-in local, content-free launcher telemetry |
| `CLAUDEX_TERRA_PROMPT_FILE` | `~/.config/claudex/terra-routing.md` | Appended native-agent routing policy |
| `CLAUDEX_BASE_URL` | `http://127.0.0.1:8317` | Local proxy URL |
| `CLAUDEX_PROXY_CONFIG` | `~/.config/claudex/cliproxyapi.yaml` | Proxy configuration |
| `CLAUDEX_TOKEN_FILE` | `~/.config/claudex/token` | Local proxy token |

`CLAUDEX_EFFORT` and a compatibility `terra` CLI `--effort` argument control only the main GPT-5.6 Sol session. Implementer, Luna, Frontend, Sol advisory, and Sol Review have fixed role efforts (`low`, `high`, `high`, `medium`, and `medium`). Frontend also fixes its agent and model to `claudex-frontend` and `gpt-5.6-terra`; its command rejects agent, model, and effort overrides. `xhigh` is unsupported and rejected before Claudex starts or probes the proxy.

Claudex bypasses Claude Code permission prompts by default. Re-enable them for one session:

```bash
CLAUDEX_SKIP_PERMISSIONS=0 claudex
```

`CLAUDEX_SKIP_PERMISSIONS=1` weakens Claude Code permission enforcement. Use `CLAUDEX_SKIP_PERMISSIONS=0` with Luna or Sol if you need their read-only guarantees enforced by the client; their definitions also prohibit mutations in their instructions.

### Local usage-efficiency snapshots

Run `claudex-usage-efficiency snapshot` to append a local-only, content-free snapshot of current Codex weekly usage percent per active coding hour. The command first queries Codex's app-server `account/rateLimits/read` method for the account's current `codex` quota bucket, including the authoritative reset time and window duration, then clips local Codex and Orca-Codex turn-duration records to that exact quota window.

```bash
claudex-usage-efficiency snapshot
claudex-usage-efficiency report
```

If Codex's app-server is unavailable, provide the same quota data manually:

```bash
claudex-usage-efficiency snapshot --no-auto-rate-limit --percent-used 73 --reset-at 2026-08-28T11:30:16Z --window-minutes 10080
```

Snapshots are appended to `${XDG_STATE_HOME:-~/.local/state}/claudex/usage/efficiency.jsonl` with private directory/file permissions. Records contain only aggregate quota-window timestamps, cumulative percent used, merged active seconds/hours, derived percent per active hour, source revisions, and aggregate source counts. They do not contain prompts, transcripts, repositories, raw database paths, session IDs, thread IDs, intervals, credentials, or environment values. Report mode compares only snapshots from the same quota window with compatible format/source revisions and nondecreasing cumulative percent/hours; resets, pruned source data, zero-hour deltas, and incompatible revisions are reported as non-comparable rather than as efficiency changes.

This is retrospective, explicitly user-invoked accounting. It does not install hooks, poll, watch processes, infer lifecycle state, resume, restart, steer, or send data externally.

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

## Troubleshooting

- **`claudex: command not found`:** restart the shell, or source its startup file. Confirm that `~/.local/bin` is in `PATH`.
- **Agents are missing:** restart an already-open Claude Code session or run `/agents` to reload custom agents.
- **OAuth was skipped or expired:** run the re-authentication command above, complete the browser/device flow, then rerun the authenticated smoke test.
- **Proxy fails to start:** inspect `~/.config/claudex/cliproxyapi.log`. Another process may already be using `127.0.0.1:8317`; stop or reconfigure that process before retrying.
- **Config/token consistency error:** restore both `~/.config/claudex/cliproxyapi.yaml` and `~/.config/claudex/token` from the same installation, or move both aside and rerun the installer to generate a fresh pair. Do not delete OAuth credentials unless intentionally re-authenticating.
- **Config permission or symlink refusal:** Claudex requires a regular `~/.config/claudex` directory at mode `700` and regular config/token files at mode `600`. Follow the installer's exact `chmod` guidance; replace symlinks with private regular files before retrying.
- **Installation stops after managed writes:** use the backup ID printed by the failure handler with `./scripts/uninstall.sh --restore-backup BACKUP_ID`. The interrupted run is finalized to its actual on-disk state so rollback remains hash-checked.
- **Local verification fails:** rerun `./scripts/verify-install.sh` from an up-to-date clone and follow the exact mismatched path it reports. Reinstall only after preserving intentional edits.

## Backups, rollback, and uninstall

List the available install snapshots:

```bash
./scripts/uninstall.sh --list-backups
```

Roll back one selected installation run to its immediately preceding state:

```bash
./scripts/uninstall.sh --restore-backup BACKUP_ID
```

Remove unchanged Claudex-managed files and restore the original pre-Claudex files:

```bash
./scripts/uninstall.sh --restore-original
```

Restore and uninstall are deliberately conservative. Before changing anything, they verify that every managed path still matches the recorded installed hash. If any path changed afterward, the entire restore is refused and the edited files are listed. Preserve or reconcile those edits, return the managed files to the recorded state, and rerun the command.

Uninstall never removes Homebrew, Claude Code, Codex, CLIProxyAPI, proxy config/token, OAuth credentials, telemetry, backup history, or unknown sibling files. These may be shared or needed for recovery. Remove them manually only after deciding they are no longer needed. Keep the repository clone until rollback or uninstall is complete because the recovery commands live under `scripts/`.

## Update

```bash
cd claudex
git pull
./install.sh --skip-login
```

That reinstall step validates the current config/token pair, creates a new rollback snapshot, and refreshes the installed Terra routing prompt, Claude Code agent definitions, and Codex/Orca workflow config from the repository sources. `--skip-login` leaves authentication unverified; rerun the authenticated smoke test before claiming the update works end to end.

Always update through `install.sh`; direct workflow sync is intentionally unsupported because it would bypass recovery snapshots and invalidate ownership hashes. The installer copies `codex/AGENTS.md`, `codex/agents`, and `codex/skills` into `~/.codex` and into an existing or explicitly enabled Orca Codex runtime, then enforces the Claudex three-subagent concurrency cap.

Update dependencies separately when needed:

```bash
brew upgrade cliproxyapi
brew upgrade --cask codex
claude update
```

## Repo-backed workflow assets

This repository also backs up reusable local workflow assets:

- `codex/` — Claudex-aligned Codex/Orca assets installed through `./install.sh`; its internal sync step is not a standalone update interface.
  - `codex/AGENTS.md` — global Codex/Orca routing policy matching the Claude Code coordinator rules, review gates, and session-supervision boundaries.
  - `codex/agents/` — Codex subagent definitions: Claudex roles (`claudex-luna`, `claudex-sol`, `claudex-sol-review`, `claudex-frontend`) plus compatibility/fallback roles (`default`, `worker`, `worker_high`, `explorer`, `clerical`, `architect`).
  - `codex/skills/` — reusable Codex skills for Claudex routing, ClickUp task lookup/status/sync helpers, smart commits, mirror deployment, iOS simulator verification, Supabase SQL/push workflows, and Orca CLI/runtime configuration.
- `tests/run.sh` — repository regression test harness covering shell syntax, installation/recovery behavior, routing policy invariants, review receipts, telemetry privacy, usage-efficiency accounting, Codex/Orca sync, and README documentation requirements.
- `actions/buzz-repo-notifier/` — reusable Buzz repository notification GitHub/Forgejo action source and bundled `dist/` entry point.

## Security

- No API keys, OAuth credentials, local tokens, transcripts, or user settings are committed.
- The generated proxy binds only to `127.0.0.1`.
- Treat private repositories as if they could eventually become public.
- Never commit `~/.cli-proxy-api`, `~/.config/claudex/token`, or generated proxy configuration.

Claude Code documentation: <https://code.claude.com/docs/en/setup>
