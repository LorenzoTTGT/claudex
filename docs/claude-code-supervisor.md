# Claude Code Session Supervision

> **Status: policy and documentation only.** Claudex does not currently install hooks, autonomously monitor sessions, launch Claude Code child processes, read transcripts, select a session, or synthesize a resume request. User-supplied native Claude Code arguments, including `claudex --resume`, remain transparent launcher passthrough rather than Claudex supervisor control. This document records official Claude Code interfaces that may support a future reviewed supervisor; it does not authorize implementation.

## Why this matters

A Claudex session can appear quiet after a short summary even while it is working, waiting for a tool, compacting context, awaiting input, or suffering a local delivery failure. **Do not infer that a thread has stopped because it has been quiet for two minutes.** Silence is not an authoritative lifecycle signal.

A future global supervisor must distinguish a completed turn from a completed session and must never automatically replay an ambiguous operation.

## Official interfaces assessed

| Interface | Documented role | Claudex interpretation |
| --- | --- | --- |
| [Hooks](https://code.claude.com/docs/en/hooks.md) | In-process lifecycle callbacks | Useful for bounded local guards or notification only; not a durable external control plane. |
| [Sessions](https://code.claude.com/docs/en/sessions) | Local conversation persistence and explicit session resumption | A known session can be resumed, but availability does not prove it is safe to resume. |
| [Headless mode](https://code.claude.com/docs/en/headless) | `claude -p` with structured `json` and `stream-json` output | Candidate structured event/result channel for a future isolated qualification. |
| [Agent SDK sessions](https://code.claude.com/docs/en/agent-sdk/sessions) | Programmatic session identity and resume | Preferred future candidate for a product-owned long-running supervisor. |
| [Agent View](https://code.claude.com/docs/en/agent-view) | Local background-session inspection and controls | `claude agents --json` is a supplementary same-machine signal, not durable reconciliation proof. |

The public interfaces were assessed on **2026-08-10**. Documentation may change; a future implementation must independently revalidate the exact supported Claude Code version and interface behavior.

## Hook semantics and limits

### `Stop`

A `Stop` hook runs when Claude Code is attempting to finish a **turn**. It can block that turn, so an owner-installed hook may eventually enforce a narrow in-process invariant. It does not prove that the task, session, or process is safely complete. It is not permission for another process to resume a thread.

### `Notification`

Documented notifications include idle prompts, a need for user input, and completed agents. They are advisory side effects. They cannot establish exclusive ownership, prove process liveness, block a turn, or trigger continuation.

### `SessionStart`, `SessionEnd`, and `StopFailure`

`SessionStart` may inject startup/resume context. `SessionEnd` supports termination cleanup. `StopFailure` observes a turn that ended with an API error. None grants restart authority. A missing or delayed hook, a lost notification, an API error, a signal, malformed output, or a nonzero exit remains `unknown` unless later reviewed structured evidence proves a narrower state.

## Current Claudex policy

Claudex’s current `bin/claudex` launcher deliberately delegates session lifecycle to Claude Code. It does not interpret hook events, call `claude agents --json`, synthesize `--resume`, select a prior session, or persist session identifiers. A user may supply native Claude Code arguments such as `--resume`, and the launcher passes them through unchanged; that user-directed behavior is not Claudex lifecycle control.

`CLAUDEX_TELEMETRY=1` is a narrow exception for content-free, invocation-scoped aggregate launcher accounting. It may record only the launcher’s direct child elapsed time and exit result plus proxy-start/readiness observations. Those fields are not evidence that a session completed or a proxy request succeeded, and telemetry must not inspect content, infer lifecycle state, poll, retry, resume, restart, or steer Claude Code.

`claudex-usage-efficiency` is a separate, explicitly user-invoked retrospective accounting tool. It may read Codex's current account quota window through the local app-server `account/rateLimits/read` method and local Codex/Orca-Codex SQLite turn-duration timestamps, then append only aggregate quota-window, cumulative-percent, merged active-duration, and revision fields to a private local JSONL file. It must not install hooks, run continuously, poll, watch processes, persist session/thread IDs, store intervals, read prompts or transcripts, infer lifecycle state, retry work, resume, restart, steer, or send data externally.

The source-controlled [Terra routing policy](../prompts/terra-routing.md) requires the following boundary for all current and future work:

- Do not treat hook events, local agent view state, silence, or a short final summary as proof that a session is dead.
- Do not implement automatic resume, restart, or steering based on those signals.
- Do not add an executable path, command template, forwarded environment, transcript capture, credential handling, or arbitrary session-control input to configuration.

## Future evidence-backed supervisor path

A future implementation needs a separately approved design and qualification. The progression is intentionally narrow:

1. **Observation/notification policy only:** owner-installed hooks may eventually record bounded local diagnostics or notify a human. They cannot control work.
2. **Isolated qualification:** after security and architecture review, test a fixed executable, clean private configuration roots, native authentication boundaries, bounded structured output, opaque session identity, and an exclusive operation lease.
3. **Managed driver:** only after evidence establishes durable control semantics, use `stream-json` or Agent SDK results as structured evidence and treat `claude agents --json` only as an additional local observation.

A future monitored driver must separate `running`, `awaiting-input`, `turn-completed`, `api-failed`, `process-interrupted`, `stopped`, and `unknown`. It must not infer `completed`, `missing`, or `unreachable` from silence, timeout, malformed output, hook loss, or a nonzero exit.

## Future continuation requirements

If a later qualification proves safe continuation, it may use an explicit known session identifier with `claude -p "Continue the work" --resume <session-id>` or an Agent SDK resume. It must never use ambient “most recent session” selection for a global multi-session supervisor.

Before a resume can even be proposed, all of the following must be proven through safe, content-free metadata:

- an opaque session ID is known and bound to the reviewed invocation;
- the prior owner/process is definitively absent or has released an exclusive per-session lease;
- no ambiguous launch, resume, steer, or stop operation awaits reconciliation;
- required fixed settings, MCP configuration, and plugin policy are reapplied through a reviewed interface;
- a user-configured continuation policy permits the action; and
- the operation has durable no-redelivery and reconciliation rules.

Resumption restores conversation history, but does not by itself prove that all launch options or local configuration are recreated. Raw prompts, transcripts, workspace paths, credentials, provider payloads, stdout/stderr, process IDs, and content-derived hashes must not enter Claudex durable state or review artifacts.
