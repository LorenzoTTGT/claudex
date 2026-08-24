#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT_DIR/bin/claudex-review-receipt"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}

bash -n "$ROOT_DIR/bin/claudex" "$ROOT_DIR/bin/claudex-review-receipt" "$ROOT_DIR/install.sh" "$ROOT_DIR/scripts/sync-codex-orca.sh" "$ROOT_DIR/scripts/verify-install.sh" "$ROOT_DIR/scripts/uninstall.sh"
python3 - "$ROOT_DIR/scripts/install-state.py" "$TMP_DIR/install-state.pyc" <<'PY'
import py_compile, sys
py_compile.compile(sys.argv[1], cfile=sys.argv[2], doraise=True)
PY
test -f "$ROOT_DIR/agents/claudex-terra.md"
test -f "$ROOT_DIR/agents/claudex-luna.md"
test -f "$ROOT_DIR/agents/claudex-sol.md"
test -f "$ROOT_DIR/agents/claudex-sol-review.md"
test -f "$ROOT_DIR/agents/claudex-frontend.md"
test -f "$ROOT_DIR/prompts/terra-routing.md"
test -x "$ROOT_DIR/scripts/verify-install.sh"
test -x "$ROOT_DIR/scripts/uninstall.sh"
test -x "$ROOT_DIR/scripts/install-state.py"
grep -Fq '### Agent installation contract' "$ROOT_DIR/README.md" || fail 'README must define the agent installation contract'
grep -Fq '## Human quick start' "$ROOT_DIR/README.md" || fail 'README must provide a human quick start'
grep -Fq '## Backups, rollback, and uninstall' "$ROOT_DIR/README.md" || fail 'README must document recovery and uninstall'
grep -Fq 'Do not report an operational installation until this succeeds.' "$ROOT_DIR/README.md" || fail 'README must distinguish local verification from authenticated operation'
grep -Fq 'unknown sibling files are preserved' "$ROOT_DIR/README.md" || fail 'README must disclose managed-file preservation behavior'
grep -Fq 'Treat an explicit user request containing `plan`, `planning`, `architecture`, or `architectural` as a direct Sol trigger' "$ROOT_DIR/codex/AGENTS.md" || fail 'Codex AGENTS policy must treat operative plan and architecture words as direct Sol triggers'
grep -Fq 'Before the root finalizes, presents, approves, or reviews any implementation plan' "$ROOT_DIR/codex/AGENTS.md" || fail 'Codex AGENTS policy must require Sol for every implementation plan'
grep -Fq 'Use whenever a user asks to plan, review a plan, discuss planning, make or review an architecture choice' "$ROOT_DIR/codex/skills/claudex-routing/SKILL.md" || fail 'routing skill description must trigger on plan and architecture requests'
grep -Fq 'Invoke whenever the root creates, presents, approves, or reviews an implementation plan' "$ROOT_DIR/agents/claudex-sol.md" || fail 'Claude Sol description must define the mandatory plan trigger'
grep -Fq 'Invoke whenever the root creates, presents, approves, or reviews an implementation plan' "$ROOT_DIR/codex/agents/claudex-sol.toml" || fail 'Codex Sol description must define the mandatory plan trigger'
grep -Fq 'model: gpt-5.5' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Coordinator must use GPT-5.5'
grep -Fq 'effort: medium' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Coordinator must use medium effort'
grep -Fq 'effort: high' "$ROOT_DIR/agents/claudex-luna.md" || fail 'Luna must remain high effort'
grep -Fq 'effort: medium' "$ROOT_DIR/agents/claudex-sol.md" || fail 'Sol advisory must use medium effort'
grep -Fq 'effort: medium' "$ROOT_DIR/agents/claudex-sol-review.md" || fail 'Sol Review must use medium effort'
grep -Fq 'model: gpt-5.6-terra' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must use Terra'
grep -Fq 'effort: high' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must use high effort'
grep -Fq 'permissionMode: default' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must have implementation permissions'
grep -Fq 'Do not change backend logic, schemas, contracts, authentication or authorization' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must retain its narrow write boundary'
grep -Fq 'Do not monitor, infer lifecycle state, poll, resume, restart, steer, or inject continuation.' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must not introduce session supervision'
grep -Fq 'Use `claudex-sol` at medium effort for mandatory scoped feedback' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must define Sol as a mandatory medium-effort advisory'
grep -Fq 'Treat an explicit user request containing `plan`, `planning`, `architecture`, or `architectural` as a direct Sol trigger' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must treat operative plan and architecture words as direct Sol triggers'
grep -Fq 'Before the coordinator finalizes, presents, approves, or reviews any implementation plan' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require Sol for every implementation plan'
grep -Fq 'Before it makes, presents, approves, or reviews any architecture choice' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require Sol for every architecture choice'
grep -Fq 'Invoke Sol again when the plan is materially revised or a new architecture choice is introduced.' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must re-invoke Sol after material replanning or a new architecture choice'
grep -Fq 'A trivial direct edit that needs neither a plan nor an architecture choice does not trigger Sol' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must preserve the trivial direct-edit exception'
grep -Fq 'the Sol advisory is additional to and never satisfies or replaces either independent `claudex-sol-review` gate' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must keep Sol advisory separate from Sol Review gates'
grep -Fq 'medium-effort `claudex-sol-review` review before the GPT-5.5 coordinator approves the plan or starts implementation' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require medium-effort Sol Review before consequential implementation'
grep -Fq 'another independent medium-effort `claudex-sol-review` review before it treats the change as complete or merge-ready' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require medium-effort Sol Review before consequential completion'
grep -Fq 'at most three concurrently' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must cap concurrent subagents at three'
grep -Fq 'A generic planning agent is not a substitute for Sol review.' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must reject generic planning as a Sol substitute'
grep -Fq 'Prefer root-cause fixes over workaround layers.' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require root-cause fixes'
grep -Fq 'Verify actual runtime behavior rather than treating configuration' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require runtime evidence'
grep -Fq 'Before asking Sol to review a diff, state the intended behavior' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require intent-framed review'
grep -Fq 'feedback loop that fails on the exact reported symptom' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require exact-symptom reproduction'
grep -Fq 'derive expected results independently from the implementation under test' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require independent test oracles'
grep -Fq 'keeps `Behavior/Spec` findings separate from `Repository Standards` findings' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must separate review axes'
grep -Fq 'Apply YAGNI: implement only the current requirement' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must enforce YAGNI'
grep -Fq 'Add focused tests for meaningful current behavior' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require focused tests'
grep -Fq 'Match ceremony to task size' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must scale ceremony to task size'
grep -Fq 'Review feedback must not expand the user' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must prevent review scope creep'
grep -Fq 'Lead summaries, commit messages, and pull-request descriptions with the user-visible problem and outcome' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require problem-first communication'
grep -Fq 'Skill descriptions define precise trigger conditions' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must keep skill descriptions trigger-focused'
grep -Fq 'Sol Review returns PASS, CHANGES_REQUIRED, or BLOCKED' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must reserve verdicts for Sol Review'
grep -Fq 'Use `claudex-frontend` at high effort for bounded GUI/frontend implementation' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must define Frontend routing'
grep -Fq 'Frontend implementation and tests never substitute for `claudex-sol-review`.' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must retain Sol Review gates for Frontend work'
grep -Fq 'maintain a small in-context checklist of the accepted outcomes' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require in-context task tracking'
grep -Fq 'perform it now rather than responding with an intention to do it' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require available work instead of deferred intentions'
grep -Fq 'every accepted outcome within that scope is complete with concrete evidence' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require reconciled completion evidence'
grep -Fq 'it does not waive completing the requested plan, analysis, review, or checkpoint' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require complete read-only scope'
grep -Fq 'do not persist task or session state, infer lifecycle state, monitor, poll, resume, restart, steer, or inject a continuation' "$ROOT_DIR/prompts/terra-routing.md" || fail 'completion contract must not introduce session supervision'
test -f "$ROOT_DIR/docs/claude-code-supervisor.md" || fail 'Claudex must retain its Claude Code session supervision assessment'
grep -Fq 'Do not infer that a Claude Code/Claudex session is dead because it has been quiet' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must reject silence as a session-death signal'
grep -Fq 'Do not implement or install session monitoring, lifecycle observation machinery, agent-view polling, process watchers, session-state persistence, automatic resume, restart, or steering from those signals.' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must prohibit unreviewed monitoring and hook-driven lifecycle control'
grep -Fq 'known opaque session ID, structured authoritative evidence, exclusive per-session ownership or lease' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require reviewed continuation prerequisites'
grep -Fq 'does not currently autonomously monitor, restart, select, or resume Claude Code sessions.' "$ROOT_DIR/README.md" || fail 'README must preserve the docs-only supervision boundary'
grep -Fq 'User-supplied Claude Code arguments, including `claudex --resume`, are transparently passed through' "$ROOT_DIR/README.md" || fail 'README must distinguish native user-directed resume from supervisor control'
grep -Fq 'policy and documentation only' "$ROOT_DIR/docs/claude-code-supervisor.md" || fail 'assessment must retain policy-only status'
grep -Fq 'does not currently install hooks, autonomously monitor sessions' "$ROOT_DIR/docs/claude-code-supervisor.md" || fail 'assessment must prohibit installed hooks and autonomous monitoring'
grep -Fq 'Do not infer that a thread has stopped because it has been quiet for two minutes.' "$ROOT_DIR/docs/claude-code-supervisor.md" || fail 'assessment must reject silence as session-death proof'
grep -Fq 'must never use ambient “most recent session” selection' "$ROOT_DIR/docs/claude-code-supervisor.md" || fail 'assessment must require explicit session selection'
grep -Fq 'Before a resume can even be proposed' "$ROOT_DIR/docs/claude-code-supervisor.md" || fail 'assessment must retain continuation prerequisites'
! grep -Fq 'agents --json' "$ROOT_DIR/bin/claudex" || fail 'launcher must not poll local agent view'
! grep -Fq 'session_id' "$ROOT_DIR/bin/claudex" || fail 'launcher must not persist session identifiers'
! grep -Fq 'hooks' "$ROOT_DIR/install.sh" || fail 'installer must not install lifecycle hooks'
grep -Fq 'Use `claudex-sol` at medium effort for mandatory scoped feedback' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must define Sol as a mandatory medium-effort advisory'
grep -Fq 'Treat an explicit user request containing `plan`, `planning`, `architecture`, or `architectural` as a direct Sol trigger' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must treat operative plan and architecture words as direct Sol triggers'
grep -Fq 'Before you finalize, present, approve, or review any implementation plan' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must require Sol for every implementation plan'
grep -Fq 'Before you make, present, approve, or review any architecture choice' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must require Sol for every architecture choice'
grep -Fq 'Invoke Sol again when the plan is materially revised or a new architecture choice is introduced.' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must re-invoke Sol after material replanning or a new architecture choice'
grep -Fq 'A trivial direct edit that needs neither a plan nor an architecture choice does not trigger Sol' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must preserve the trivial direct-edit exception'
grep -Fq 'the Sol advisory is additional to and never satisfies or replaces either independent `claudex-sol-review` gate' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must keep Sol advisory separate from Sol Review gates'
grep -Fq 'medium-effort `claudex-sol-review` review before you approve the plan or start implementation' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Coordinator agent must require medium-effort Sol Review before consequential implementation'
grep -Fq 'another independent medium-effort `claudex-sol-review` review before you treat the change as complete or merge-ready' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Coordinator agent must require medium-effort Sol Review before consequential completion'
grep -Fq 'Use `claudex-frontend` at high effort for a bounded, non-overlapping frontend change area' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must define bounded Frontend authority'
grep -Fq 'Frontend implementation and tests never substitute for `claudex-sol-review`' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must retain Sol Review gates for Frontend work'
grep -Fq 'maintain an in-context checklist of accepted outcomes' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must require in-context task tracking'
grep -Fq 'perform it rather than responding with an intention to do it later' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must require available work instead of deferred intentions'
grep -Fq 'concrete evidence for every accepted outcome within that scope' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must require reconciled completion evidence'
grep -Fq 'it does not waive completing that requested work with the available evidence' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must require complete read-only scope'
grep -Fq 'Do not persist task or session state.' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must prohibit task and session persistence'
grep -Fq 'Do not infer lifecycle state, monitor, poll, resume, restart, steer, or inject a continuation.' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent completion contract must not add supervision'
grep -Fq 'Fix the root cause rather than adding workaround layers.' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Coordinator must require root-cause fixes'
grep -Fq 'Verify actual runtime behavior rather than treating configuration' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Coordinator must require runtime evidence'
grep -Fq 'State the intended behavior before evaluating the diff.' "$ROOT_DIR/agents/claudex-sol-review.md" || fail 'Sol Review must establish intent before findings'
grep -Fq '\"intent\":\"...\"' "$ROOT_DIR/bin/claudex" || fail 'Sol review launcher must request explicit intent'
grep -Fq '\"axis\":\"Behavior/Spec|Repository Standards\"' "$ROOT_DIR/bin/claudex" || fail 'Sol review launcher must classify review findings'
grep -Fq 'Do not invent repository standards.' "$ROOT_DIR/agents/claudex-sol-review.md" || fail 'Sol Review must not invent generic standards'
grep -Fq 'Do not let review feedback expand the change beyond the delegated goal.' "$ROOT_DIR/agents/claudex-sol-review.md" || fail 'Sol Review must preserve scope'
grep -Fq 'carries available investigation, implementation, validation, and integration steps through to completion' "$ROOT_DIR/README.md" || fail 'README must document same-session execution'
grep -Fq 'limits the requested scope; Terra still completes that requested analysis or checkpoint with the available evidence' "$ROOT_DIR/README.md" || fail 'README must describe complete limited-scope work'
grep -Fq 'not lifecycle automation: it adds no hooks, polling, process watching, task/session persistence, automatic resume/restart, session selection, or synthetic continuation' "$ROOT_DIR/README.md" || fail 'README must distinguish completion discipline from session supervision'
grep -Fq 'account/rateLimits/read' "$ROOT_DIR/README.md" || fail 'README must document automatic Codex usage percentage reads'
grep -Fq 'explicitly user-invoked retrospective usage-efficiency snapshots' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must authorize only narrow usage-efficiency accounting'
grep -Fq 'claudex-usage-efficiency` is a separate, explicitly user-invoked retrospective accounting tool' "$ROOT_DIR/docs/claude-code-supervisor.md" || fail 'supervision docs must authorize the usage-efficiency boundary'
python3 - "$ROOT_DIR/bin/claudex-usage-efficiency" "$TMP_DIR/claudex-usage-efficiency.pyc" <<'PY'
import py_compile, sys
py_compile.compile(sys.argv[1], cfile=sys.argv[2], doraise=True)
PY

USAGE_HOME="$TMP_DIR/usage-home"
USAGE_ORCA="$TMP_DIR/usage-orca"
USAGE_BIN="$TMP_DIR/usage-bin"
USAGE_STATE="$TMP_DIR/usage-state"
mkdir -p "$USAGE_HOME" "$USAGE_ORCA" "$USAGE_BIN" "$USAGE_STATE"
python3 - "$USAGE_HOME/thread_history_1.sqlite" "$USAGE_ORCA/thread_history_1.sqlite" <<'PY'
import sqlite3, sys
schema = """
CREATE TABLE thread_turns (
    thread_id TEXT NOT NULL,
    turn_id TEXT NOT NULL,
    rollout_ordinal INTEGER NOT NULL,
    status TEXT NOT NULL,
    error_json TEXT,
    started_at INTEGER,
    completed_at INTEGER,
    duration_ms INTEGER,
    first_user_item_id TEXT,
    final_agent_item_id TEXT,
    rollout_byte_offset INTEGER,
    rollout_end_ordinal INTEGER,
    rollout_end_byte_offset INTEGER,
    PRIMARY KEY (thread_id, turn_id)
)
"""
for path, start, end in [(sys.argv[1], 1700003600, 1700007200), (sys.argv[2], 1700005400, 1700009000)]:
    con = sqlite3.connect(path)
    con.executescript(schema)
    con.execute("INSERT INTO thread_turns (thread_id, turn_id, rollout_ordinal, status, started_at, completed_at, duration_ms) VALUES ('thread', 'turn', 1, 'completed', ?, ?, ?)", (start, end, (end - start) * 1000))
    con.commit()
    con.close()
PY
cat >"$USAGE_BIN/codex" <<'EOF'
#!/usr/bin/env python3
import json, sys
for line in sys.stdin:
    message = json.loads(line)
    if message.get("id") == 1:
        print(json.dumps({"id": 1, "result": {"userAgent": "test", "codexHome": "/tmp/test", "platformFamily": "unix", "platformOs": "macos"}}), flush=True)
    elif message.get("id") == 2:
        print(json.dumps({"id": 2, "result": {"rateLimits": {"limitId": "other", "primary": {"usedPercent": 99, "windowDurationMins": 10080, "resetsAt": 1700604800}}, "rateLimitsByLimitId": {"codex": {"limitId": "codex", "primary": {"usedPercent": 15, "windowDurationMins": 10080, "resetsAt": 1700604800}}}}}), flush=True)
EOF
chmod 755 "$USAGE_BIN/codex"
env PATH="$USAGE_BIN:$PATH" CODEX_HOME="$USAGE_HOME" ORCA_CODEX_HOME="$USAGE_ORCA" XDG_STATE_HOME="$USAGE_STATE" "$ROOT_DIR/bin/claudex-usage-efficiency" snapshot --json >"$TMP_DIR/usage-snapshot.json"
python3 - "$TMP_DIR/usage-snapshot.json" "$USAGE_STATE/claudex/usage/efficiency.jsonl" <<'PY'
import json, os, stat, sys
snapshot = json.load(open(sys.argv[1]))
store = sys.argv[2]
assert snapshot["percent_used"] == 15, snapshot
assert snapshot["quota_window_start_unix"] == 1700000000, snapshot
assert snapshot["quota_window_end_unix"] == 1700604800, snapshot
assert snapshot["active_seconds"] == 5400, snapshot
assert snapshot["active_hours"] == 1.5, snapshot
assert snapshot["percent_per_active_hour"] == 10, snapshot
assert snapshot["db_source_counts"] == {"codex": 1, "orca": 1}, snapshot
assert snapshot["rate_limit_source"] == "codex_app_server_account_rateLimits_read", snapshot
mode = stat.S_IMODE(os.stat(store).st_mode)
assert mode == 0o600, oct(mode)
assert len(open(store).read().splitlines()) == 1
for forbidden in ["thread", "turn", sys.argv[1], os.environ.get("HOME", "")]:
    if forbidden:
        assert forbidden not in open(store).read(), forbidden
PY
USAGE_LINK_HOME="$TMP_DIR/usage-link-home"
mkdir -p "$USAGE_LINK_HOME"
ln -s "$USAGE_HOME/thread_history_1.sqlite" "$USAGE_LINK_HOME/thread_history_1.sqlite"
expect_fail env CODEX_HOME="$USAGE_LINK_HOME" CLAUDEX_USAGE_INCLUDE_ORCA=0 XDG_STATE_HOME="$TMP_DIR/usage-link-state" "$ROOT_DIR/bin/claudex-usage-efficiency" snapshot --no-auto-rate-limit --percent-used 1 --reset-at 1700604800 --window-minutes 10080
USAGE_DIRECTORY_DB_HOME="$TMP_DIR/usage-directory-db-home"
mkdir -p "$USAGE_DIRECTORY_DB_HOME/thread_history_1.sqlite"
expect_fail env CODEX_HOME="$USAGE_DIRECTORY_DB_HOME" CLAUDEX_USAGE_INCLUDE_ORCA=0 XDG_STATE_HOME="$TMP_DIR/usage-directory-db-state" "$ROOT_DIR/bin/claudex-usage-efficiency" snapshot --no-auto-rate-limit --percent-used 1 --reset-at 1700604800 --window-minutes 10080
cat >"$USAGE_BIN/codex" <<'EOF'
#!/usr/bin/env python3
import json, sys
for line in sys.stdin:
    message = json.loads(line)
    if message.get("id") == 1:
        print(json.dumps({"id": 1, "result": {"userAgent": "test", "codexHome": "/tmp/test", "platformFamily": "unix", "platformOs": "macos"}}), flush=True)
    elif message.get("id") == 2:
        print(json.dumps({"id": 2, "result": {"rateLimits": {"limitId": "other", "primary": {"usedPercent": 15, "windowDurationMins": 10080, "resetsAt": 1700604800}}}}), flush=True)
EOF
chmod 755 "$USAGE_BIN/codex"
expect_fail env PATH="$USAGE_BIN:$PATH" CODEX_HOME="$USAGE_HOME" CLAUDEX_USAGE_INCLUDE_ORCA=0 XDG_STATE_HOME="$TMP_DIR/usage-wrong-bucket-state" "$ROOT_DIR/bin/claudex-usage-efficiency" snapshot

INSTALL_HOME="$TMP_DIR/install-home"
INSTALL_XDG="$TMP_DIR/install-xdg"
INSTALL_MOCK_BIN="$TMP_DIR/install-mock-bin"
mkdir -p "$INSTALL_HOME" "$INSTALL_XDG" "$INSTALL_MOCK_BIN"
CLAUDE_ARGS_LOG="$TMP_DIR/claude-args.log"
cat >"$INSTALL_MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${CLAUDE_ARGS_LOG:?}"
EOF
cat >"$INSTALL_MOCK_BIN/cliproxyapi" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$INSTALL_MOCK_BIN/codex" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$INSTALL_MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 755 "$INSTALL_MOCK_BIN/claude" "$INSTALL_MOCK_BIN/cliproxyapi" "$INSTALL_MOCK_BIN/codex" "$INSTALL_MOCK_BIN/curl"
env \
  HOME="$INSTALL_HOME" \
  XDG_CONFIG_HOME="$INSTALL_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login >/dev/null
INSTALLED_PROMPT="$INSTALL_XDG/claudex/terra-routing.md"
INSTALLED_AGENT_HOME="$INSTALL_HOME/.claude/agents"
cmp -s "$ROOT_DIR/prompts/terra-routing.md" "$INSTALLED_PROMPT" || fail 'install.sh must install the current routing prompt'
for agent in claudex-terra claudex-luna claudex-frontend claudex-sol claudex-sol-review; do
  cmp -s "$ROOT_DIR/agents/$agent.md" "$INSTALLED_AGENT_HOME/$agent.md" || fail "install.sh must install $agent"
done
test -x "$INSTALL_HOME/.local/bin/claudex-usage-efficiency" || fail 'install.sh must install the usage-efficiency utility'
cmp -s "$ROOT_DIR/codex/AGENTS.md" "$INSTALL_HOME/.codex/AGENTS.md" || fail 'install.sh must install repo-backed Codex policy'
cmp -s "$ROOT_DIR/codex/agents/claudex-luna.toml" "$INSTALL_HOME/.codex/agents/claudex-luna.toml" || fail 'install.sh must install repo-backed Codex agents'
cmp -s "$ROOT_DIR/codex/skills/claudex-routing/SKILL.md" "$INSTALL_HOME/.codex/skills/claudex-routing/SKILL.md" || fail 'install.sh must install repo-backed Codex skills'
grep -Fq 'max_threads = 3' "$INSTALL_HOME/.codex/config.toml" || fail 'install.sh must cap Codex subagent threads at three'
test ! -e "$INSTALL_HOME/Library/Application Support/orca/codex-runtime-home/home" || fail 'install.sh must not create an absent default Orca runtime'
AUTO_ORCA_HOME="$TMP_DIR/auto-orca-home"
mkdir -p "$AUTO_ORCA_HOME/Library/Application Support/orca/codex-runtime-home/home"
mkdir -p "$AUTO_ORCA_HOME/.codex"
printf '%s\n' '[agents]' 'max_threads = 9' 'max_depth = 2' >"$AUTO_ORCA_HOME/.codex/config.toml"
printf '%s\n' 'pre-sync policy' >"$AUTO_ORCA_HOME/.codex/AGENTS.md"
ln -s "$AUTO_ORCA_HOME/.codex/AGENTS.md" "$AUTO_ORCA_HOME/Library/Application Support/orca/codex-runtime-home/home/AGENTS.md"
HOME="$AUTO_ORCA_HOME" CODEX_HOME="$AUTO_ORCA_HOME/.codex" CLAUDEX_SYNC_INTERNAL=1 "$ROOT_DIR/scripts/sync-codex-orca.sh" >/dev/null
cmp -s "$ROOT_DIR/codex/AGENTS.md" "$AUTO_ORCA_HOME/Library/Application Support/orca/codex-runtime-home/home/AGENTS.md" || fail 'an existing default Orca runtime must be detected and synced'
test -L "$AUTO_ORCA_HOME/Library/Application Support/orca/codex-runtime-home/home/AGENTS.md" || fail 'Orca sync must preserve a policy link shared with the primary Codex home'
grep -Fq 'max_depth = 1' "$AUTO_ORCA_HOME/.codex/config.toml" || fail 'workflow sync must replace an existing noncompliant max_depth value'
! grep -Fq 'max_depth = 2' "$AUTO_ORCA_HOME/.codex/config.toml" || fail 'workflow sync must not retain a stale max_depth value'
UNBACKED_SYNC_HOME="$TMP_DIR/unbacked-sync-home"
expect_fail env HOME="$UNBACKED_SYNC_HOME" CODEX_HOME="$UNBACKED_SYNC_HOME/.codex" "$ROOT_DIR/scripts/sync-codex-orca.sh"
test ! -e "$UNBACKED_SYNC_HOME/.codex" || fail 'direct workflow sync must refuse to mutate without installer recovery accounting'
INSTALL_ORCA="$INSTALL_HOME/orca-runtime"
printf '%s\n' 'keep this user file' >"$INSTALL_HOME/.codex/skills/claudex-routing/user-note.txt"
env \
  HOME="$INSTALL_HOME" \
  XDG_CONFIG_HOME="$INSTALL_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  ORCA_CODEX_HOME="$INSTALL_ORCA" \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login >/dev/null
cmp -s "$ROOT_DIR/codex/agents/claudex-sol-review.toml" "$INSTALL_ORCA/agents/claudex-sol-review.toml" || fail 'an explicit Orca target must authorize creation and sync'
grep -Fq 'max_threads = 3' "$INSTALL_ORCA/config.toml" || fail 'explicit Orca sync must cap subagent threads at three'
grep -Fq 'keep this user file' "$INSTALL_HOME/.codex/skills/claudex-routing/user-note.txt" || fail 'workflow sync must preserve unknown files beside managed skill files'
printf '%s\n' 'stale prompt' >"$INSTALLED_PROMPT"
printf '%s\n' 'stale agent' >"$INSTALLED_AGENT_HOME/claudex-sol-review.md"
printf '%s\n' 'stale codex policy' >"$INSTALL_HOME/.codex/AGENTS.md"
printf '%s\n' 'stale orca agent' >"$INSTALL_ORCA/agents/claudex-sol-review.toml"
env \
  HOME="$INSTALL_HOME" \
  XDG_CONFIG_HOME="$INSTALL_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  ORCA_CODEX_HOME="$INSTALL_ORCA" \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login >/dev/null
cmp -s "$ROOT_DIR/prompts/terra-routing.md" "$INSTALLED_PROMPT" || fail 'install.sh must refresh the installed routing prompt on reinstall'
for agent in claudex-terra claudex-luna claudex-frontend claudex-sol claudex-sol-review; do
  cmp -s "$ROOT_DIR/agents/$agent.md" "$INSTALLED_AGENT_HOME/$agent.md" || fail "install.sh must refresh $agent on reinstall"
done
cmp -s "$ROOT_DIR/codex/AGENTS.md" "$INSTALL_HOME/.codex/AGENTS.md" || fail 'install.sh must refresh repo-backed Codex policy'
cmp -s "$ROOT_DIR/codex/agents/claudex-sol-review.toml" "$INSTALL_ORCA/agents/claudex-sol-review.toml" || fail 'install.sh must refresh repo-backed Orca Codex agents'

PREFLIGHT_HOME="$TMP_DIR/preflight-home"
PREFLIGHT_XDG="$TMP_DIR/preflight-xdg"
PREFLIGHT_BIN="$TMP_DIR/preflight-bin"
mkdir -p "$PREFLIGHT_HOME" "$PREFLIGHT_XDG" "$PREFLIGHT_BIN"
for command_name in chmod cmp dirname find grep install mkdir openssl sed uname; do
  ln -s "$(command -v "$command_name")" "$PREFLIGHT_BIN/$command_name"
done
expect_fail /usr/bin/env \
  HOME="$PREFLIGHT_HOME" \
  XDG_CONFIG_HOME="$PREFLIGHT_XDG" \
  PATH="$PREFLIGHT_BIN" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  /bin/bash "$ROOT_DIR/install.sh" --skip-login
test ! -e "$PREFLIGHT_XDG/claudex" || fail 'missing-prerequisite preflight must not create Claudex config'
test ! -e "$PREFLIGHT_HOME/.codex" || fail 'missing-prerequisite preflight must not create Codex workflow files'

PARTIAL_HOME="$TMP_DIR/partial-home"
PARTIAL_XDG="$TMP_DIR/partial-xdg"
mkdir -p "$PARTIAL_XDG/claudex"
chmod 700 "$PARTIAL_XDG/claudex"
printf '%s\n' 'existing config without token' >"$PARTIAL_XDG/claudex/cliproxyapi.yaml"
expect_fail env \
  HOME="$PARTIAL_HOME" \
  XDG_CONFIG_HOME="$PARTIAL_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login
test ! -e "$PARTIAL_HOME/.local/bin/claudex" || fail 'partial proxy state must fail before launcher installation'
printf '%s\n' 'token-a' >"$PARTIAL_XDG/claudex/token"
printf '%s\n' 'api-keys: [token-b]' >"$PARTIAL_XDG/claudex/cliproxyapi.yaml"
expect_fail env \
  HOME="$PARTIAL_HOME" \
  XDG_CONFIG_HOME="$PARTIAL_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login
test ! -e "$PARTIAL_HOME/.codex" || fail 'mismatched proxy config/token must fail before workflow installation'

PERMISSION_HOME="$TMP_DIR/permission-home"
PERMISSION_XDG="$TMP_DIR/permission-xdg"
mkdir -p "$PERMISSION_XDG/claudex"
chmod 700 "$PERMISSION_XDG/claudex"
printf '%s\n' 'mode-token' >"$PERMISSION_XDG/claudex/token"
printf '%s\n' 'api-keys: [mode-token]' >"$PERMISSION_XDG/claudex/cliproxyapi.yaml"
chmod 644 "$PERMISSION_XDG/claudex/token" "$PERMISSION_XDG/claudex/cliproxyapi.yaml"
expect_fail env \
  HOME="$PERMISSION_HOME" \
  XDG_CONFIG_HOME="$PERMISSION_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login
test "$(stat -f '%Lp' "$PERMISSION_XDG/claudex/token" 2>/dev/null || stat -c '%a' "$PERMISSION_XDG/claudex/token")" = 644 || fail 'preflight must not silently change existing token permissions'
test ! -e "$PERMISSION_HOME/.local/bin/claudex" || fail 'insecure proxy permissions must fail before managed writes'

SYMLINK_HOME="$TMP_DIR/symlink-home"
SYMLINK_XDG="$TMP_DIR/symlink-xdg"
mkdir -p "$SYMLINK_HOME/private" "$SYMLINK_XDG/claudex"
chmod 700 "$SYMLINK_XDG/claudex"
printf '%s\n' 'link-token' >"$SYMLINK_HOME/private/token"
printf '%s\n' 'api-keys: [link-token]' >"$SYMLINK_HOME/private/config"
chmod 600 "$SYMLINK_HOME/private/token" "$SYMLINK_HOME/private/config"
ln -s "$SYMLINK_HOME/private/token" "$SYMLINK_XDG/claudex/token"
ln -s "$SYMLINK_HOME/private/config" "$SYMLINK_XDG/claudex/cliproxyapi.yaml"
expect_fail env \
  HOME="$SYMLINK_HOME" \
  XDG_CONFIG_HOME="$SYMLINK_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login
test ! -e "$SYMLINK_HOME/.local/bin/claudex" || fail 'symlinked proxy state must fail before managed writes'

NONREGULAR_HOME="$TMP_DIR/nonregular-home"
NONREGULAR_XDG="$TMP_DIR/nonregular-xdg"
mkdir -p "$NONREGULAR_XDG/claudex/token"
chmod 700 "$NONREGULAR_XDG/claudex"
expect_fail env \
  HOME="$NONREGULAR_HOME" \
  XDG_CONFIG_HOME="$NONREGULAR_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login
test ! -e "$NONREGULAR_HOME/.local/bin/claudex" || fail 'a non-regular proxy target must fail before managed writes'
test ! -e "$NONREGULAR_HOME/.local/state/claudex/install-backups" || fail 'a non-regular proxy target must fail before backup-state mutation'

MANAGED_LINK_HOME="$TMP_DIR/managed-link-home"
MANAGED_LINK_XDG="$TMP_DIR/managed-link-xdg"
mkdir -p "$MANAGED_LINK_HOME/.codex" "$MANAGED_LINK_HOME/private" "$MANAGED_LINK_XDG"
printf '%s\n' 'outside managed target' >"$MANAGED_LINK_HOME/private/AGENTS.md"
ln -s "$MANAGED_LINK_HOME/private/AGENTS.md" "$MANAGED_LINK_HOME/.codex/AGENTS.md"
expect_fail env \
  HOME="$MANAGED_LINK_HOME" \
  XDG_CONFIG_HOME="$MANAGED_LINK_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login
grep -Fq 'outside managed target' "$MANAGED_LINK_HOME/private/AGENTS.md" || fail 'managed-target symlink refusal must not mutate its referent'
test ! -e "$MANAGED_LINK_XDG/claudex" || fail 'managed-target symlink refusal must occur before configuration writes'

FAIL_HOME="$TMP_DIR/fail-home"
FAIL_XDG="$TMP_DIR/fail-xdg"
FAIL_BIN="$TMP_DIR/fail-bin"
mkdir -p "$FAIL_HOME" "$FAIL_XDG" "$FAIL_BIN"
cp "$INSTALL_MOCK_BIN/claude" "$INSTALL_MOCK_BIN/cliproxyapi" "$INSTALL_MOCK_BIN/codex" "$INSTALL_MOCK_BIN/curl" "$FAIL_BIN/"
cat >"$FAIL_BIN/install" <<'EOF'
#!/usr/bin/env bash
for argument in "$@"; do
  case "$argument" in */codex/AGENTS.md) exit 73 ;; esac
done
exec "${REAL_INSTALL:?}" "$@"
EOF
chmod 755 "$FAIL_BIN/"*
REAL_INSTALL="$(command -v install)"
expect_fail env \
  HOME="$FAIL_HOME" \
  XDG_CONFIG_HOME="$FAIL_XDG" \
  PATH="$FAIL_BIN:$PATH" \
  SHELL=/bin/zsh \
  REAL_INSTALL="$REAL_INSTALL" \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login
FAILED_BACKUP="$(HOME="$FAIL_HOME" XDG_STATE_HOME="$FAIL_HOME/.local/state" "$ROOT_DIR/scripts/uninstall.sh" --list-backups | tail -n 1 | cut -f 1)"
test -n "$FAILED_BACKUP" || fail 'a failed mid-install run must expose a recovery backup'
HOME="$FAIL_HOME" XDG_STATE_HOME="$FAIL_HOME/.local/state" "$ROOT_DIR/scripts/uninstall.sh" --restore-backup "$FAILED_BACKUP" >/dev/null
test ! -e "$FAIL_HOME/.local/bin/claudex" || fail 'failed-install rollback must restore the pre-install launcher state'

RESTORE_HOME="$TMP_DIR/restore-home"
RESTORE_XDG="$TMP_DIR/restore-xdg"
mkdir -p "$RESTORE_HOME/.codex/agents" "$RESTORE_HOME/.codex/skills/claudex-routing" "$RESTORE_XDG"
printf '%s\n' 'original user policy' >"$RESTORE_HOME/.codex/AGENTS.md"
printf '%s\n' 'unknown user agent' >"$RESTORE_HOME/.codex/agents/user-agent.toml"
printf '%s\n' 'unknown skill note' >"$RESTORE_HOME/.codex/skills/claudex-routing/user-note.txt"
env \
  HOME="$RESTORE_HOME" \
  XDG_CONFIG_HOME="$RESTORE_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login >/dev/null
RESTORE_STATE="$RESTORE_HOME/.local/state/claudex/install-backups"
test "$(stat -f '%Lp' "$RESTORE_STATE" 2>/dev/null || stat -c '%a' "$RESTORE_STATE")" = 700 || fail 'install backup directory must be private'
test "$(stat -f '%Lp' "$RESTORE_STATE/ownership.json" 2>/dev/null || stat -c '%a' "$RESTORE_STATE/ownership.json")" = 600 || fail 'install ownership manifest must be private'
printf '%s\n' 'pre-update local edit' >"$RESTORE_HOME/.claude/agents/claudex-sol-review.md"
env \
  HOME="$RESTORE_HOME" \
  XDG_CONFIG_HOME="$RESTORE_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login >/dev/null
LATEST_BACKUP="$(HOME="$RESTORE_HOME" XDG_STATE_HOME="$RESTORE_HOME/.local/state" "$ROOT_DIR/scripts/uninstall.sh" --list-backups | tail -n 1 | cut -f 1)"
HOME="$RESTORE_HOME" XDG_STATE_HOME="$RESTORE_HOME/.local/state" "$ROOT_DIR/scripts/uninstall.sh" --restore-backup "$LATEST_BACKUP" >/dev/null
grep -Fq 'pre-update local edit' "$RESTORE_HOME/.claude/agents/claudex-sol-review.md" || fail 'explicit rollback must restore the selected pre-install state'
printf '%s\n' 'post-install conflicting edit' >"$RESTORE_HOME/.codex/AGENTS.md"
expect_fail env HOME="$RESTORE_HOME" XDG_STATE_HOME="$RESTORE_HOME/.local/state" "$ROOT_DIR/scripts/uninstall.sh" --restore-original
grep -Fq 'post-install conflicting edit' "$RESTORE_HOME/.codex/AGENTS.md" || fail 'uninstall conflict must preserve post-install user edits'
cp "$ROOT_DIR/codex/AGENTS.md" "$RESTORE_HOME/.codex/AGENTS.md"
HOME="$RESTORE_HOME" XDG_STATE_HOME="$RESTORE_HOME/.local/state" "$ROOT_DIR/scripts/uninstall.sh" --restore-original >/dev/null
grep -Fq 'original user policy' "$RESTORE_HOME/.codex/AGENTS.md" || fail 'uninstall must restore the original pre-Claudex managed file'
test ! -e "$RESTORE_HOME/.local/bin/claudex" || fail 'uninstall must remove an unchanged Claudex-created launcher'
grep -Fq 'unknown user agent' "$RESTORE_HOME/.codex/agents/user-agent.toml" || fail 'uninstall must preserve unknown sibling agents'
grep -Fq 'unknown skill note' "$RESTORE_HOME/.codex/skills/claudex-routing/user-note.txt" || fail 'uninstall must preserve unknown sibling skill files'
test -f "$RESTORE_XDG/claudex/cliproxyapi.yaml" && test -f "$RESTORE_XDG/claudex/token" || fail 'uninstall must retain proxy config and token'
printf '%s\n' 'sentinel routing prompt from installed file' >"$INSTALLED_PROMPT"
rm -f "$CLAUDE_ARGS_LOG"
env \
  HOME="$INSTALL_HOME" \
  XDG_CONFIG_HOME="$INSTALL_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_PROXY_CONFIG="$INSTALL_XDG/claudex/cliproxyapi.yaml" \
  CLAUDEX_TOKEN_FILE="$INSTALL_XDG/claudex/token" \
  CLAUDEX_SKIP_PERMISSIONS=0 \
  CLAUDE_ARGS_LOG="$CLAUDE_ARGS_LOG" \
  "$INSTALL_HOME/.local/bin/claudex" --print 'Reply with exactly: OK' >/dev/null
grep -Fq -- '--append-system-prompt' "$CLAUDE_ARGS_LOG" || fail 'installed launcher must append the installed routing prompt'
grep -Fq 'sentinel routing prompt from installed file' "$CLAUDE_ARGS_LOG" || fail 'installed launcher must consume the installed routing prompt file'
! grep -Eq -- '^--(resume|continue)(=|$)' "$CLAUDE_ARGS_LOG" || fail 'ordinary launcher invocation must not synthesize resume or session selection arguments'

rm -f "$CLAUDE_ARGS_LOG"
env \
  HOME="$INSTALL_HOME" \
  XDG_CONFIG_HOME="$INSTALL_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_PROXY_CONFIG="$INSTALL_XDG/claudex/cliproxyapi.yaml" \
  CLAUDEX_TOKEN_FILE="$INSTALL_XDG/claudex/token" \
  CLAUDEX_SKIP_PERMISSIONS=0 \
  CLAUDE_ARGS_LOG="$CLAUDE_ARGS_LOG" \
  "$INSTALL_HOME/.local/bin/claudex" --resume session-fixture-42 >/dev/null
python3 - "$CLAUDE_ARGS_LOG" <<'PY'
import sys
args = open(sys.argv[1]).read().splitlines()
assert args.count("--resume") == 1, args
assert args.count("session-fixture-42") == 1, args
index = args.index("--resume")
assert args[index + 1] == "session-fixture-42", args
assert not any(arg == "--continue" or arg.startswith("--continue=") or arg.startswith("--resume=") for arg in args), args
PY

REPO="$TMP_DIR/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.invalid
git -C "$REPO" config user.name test
touch "$REPO/README.md"
git -C "$REPO" add README.md
git -C "$REPO" commit -qm initial
mkdir -p "$REPO/auth"
touch "$REPO/auth/session.ts"
git -C "$REPO" add auth/session.ts
printf '%s\n' 'staged' >"$REPO/fixture.txt"
git -C "$REPO" add fixture.txt
printf '%s\n' 'unstaged' >"$REPO/fixture.txt"
touch "$REPO/only-working-tree.txt"

export XDG_STATE_HOME="$TMP_DIR/state"
[[ "$(cd "$REPO" && "$GATE" classify)" == "sensitive" ]] || fail 'expected sensitive staged change'
expect_fail bash -c "cd '$REPO' && '$GATE' check"
VERIFY_TMP="$TMP_DIR/verify-tmp"
mkdir -p "$VERIFY_TMP"
expect_fail env TMPDIR="$VERIFY_TMP" bash -c "cd '$REPO' && '$GATE' verify '$TMP_DIR/verify-missing.json'"
[[ -z "$(find "$VERIFY_TMP" -mindepth 1 -print -quit)" ]] || fail 'failed verification must clean temporary files and worktrees'

REVIEW="$TMP_DIR/review.json"
printf '%s\n' '{"verdict":"PASS","summary":"reviewed","findings":[],"uncertainties":[]}' >"$REVIEW"
mkdir -p "$REPO/.claudex"
cat >"$REPO/.claudex/verify-commands" <<'EOF'
grep -qx 'staged' fixture.txt
test ! -e only-working-tree.txt
EOF
expect_fail bash -c "cd '$REPO' && '$GATE' verify '$TMP_DIR/verify-unstaged-policy.json'"
git -C "$REPO" add .claudex/verify-commands
printf '%s\n' 'false' >"$REPO/.claudex/verify-commands"

VERIFY="$TMP_DIR/verify.json"
(cd "$REPO" && "$GATE" verify "$VERIFY" >/dev/null)
python3 - "$VERIFY" <<'PY'
import json, sys
value = json.load(open(sys.argv[1]))
assert value["commands_source"] == ".claudex/verify-commands@staged-tree"
assert len(value["policy_sha256"]) == 64
assert all(len(result["stdout_sha256"]) == 64 and len(result["stderr_sha256"]) == 64 for result in value["commands"])
PY

REVIEWED_TREE="$(cd "$REPO" && git write-tree)"
touch "$REPO/race-change.txt"
git -C "$REPO" add race-change.txt
expect_fail bash -c "cd '$REPO' && '$GATE' _finalize '$REVIEW' '$REVIEWED_TREE' >/dev/null"
git -C "$REPO" rm --cached -q race-change.txt
rm -f "$REPO/race-change.txt"
(cd "$REPO" && "$GATE" _finalize "$REVIEW" "$REVIEWED_TREE" >/dev/null && "$GATE" check >/dev/null)

FAILED_VERIFY="$TMP_DIR/verify-failed.json"
printf '%s\n' '{"format":1,"staged_tree":"'"$(cd "$REPO" && git write-tree)"'","classification":"sensitive","required":true,"commands_source":"test","all_passed":false,"commands":[{"command":"false","exit_code":1,"status":"failed"}],"created_at":"2026-08-05T00:00:00Z"}' >"$FAILED_VERIFY"
expect_fail bash -c "cd '$REPO' && '$GATE' _finalize '$REVIEW' '$REVIEWED_TREE' '$FAILED_VERIFY' >/dev/null"

FORGED_VERIFY="$TMP_DIR/verify-forged.json"
printf '%s\n' '{"format":1,"staged_tree":"'"$(cd "$REPO" && git write-tree)"'","classification":"sensitive","required":true,"commands_source":"test","all_passed":true,"commands":[{"command":"false","exit_code":1,"status":"failed"}],"created_at":"2026-08-05T00:00:00Z"}' >"$FORGED_VERIFY"
expect_fail bash -c "cd '$REPO' && '$GATE' _finalize '$REVIEW' '$REVIEWED_TREE' '$FORGED_VERIFY' >/dev/null"

HOOK_REPO="$TMP_DIR/hook-repo"
mkdir -p "$HOOK_REPO/.git/hooks"
python3 - "$ROOT_DIR/hooks/pre-commit" "$HOOK_REPO/.git/hooks/pre-commit" "$GATE" <<'PY'
import pathlib, sys
template, destination, gate = sys.argv[1:]
pathlib.Path(destination).write_text(pathlib.Path(template).read_text().replace("__CLAUDEX_GATE_BIN__", gate))
PY
chmod 755 "$HOOK_REPO/.git/hooks/pre-commit"
grep -Fq "CLAUDEX_GATE_BIN=\"$GATE\"" "$HOOK_REPO/.git/hooks/pre-commit" || fail 'installed hook must bind the deterministic receipt gate'
grep -Fq 'exec "$CLAUDEX_GATE_BIN" check' "$HOOK_REPO/.git/hooks/pre-commit" || fail 'installed hook must call the deterministic receipt gate'

MOCK_BIN="$TMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN" "$TMP_DIR/config"
cat >"$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
if [[ -n "${MOCK_CLAUDE_ARGS_LOG:-}" ]]; then
  printf '%s\n' "$@" >"$MOCK_CLAUDE_ARGS_LOG"
fi
if [[ -n "${MOCK_CLAUDE_STDOUT:-}" ]]; then
  printf '%s\n' "$MOCK_CLAUDE_STDOUT"
else
  printf '{"verdict":"%s","summary":"mock review","findings":[],"uncertainties":[]}\n' "${MOCK_SOL_VERDICT:-PASS}"
fi
if [[ -n "${MOCK_CLAUDE_STDERR:-}" ]]; then
  printf '%s\n' "$MOCK_CLAUDE_STDERR" >&2
fi
exit "${MOCK_CLAUDE_EXIT:-0}"
EOF
cat >"$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$MOCK_BIN/cliproxyapi" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 755 "$MOCK_BIN/claude" "$MOCK_BIN/curl" "$MOCK_BIN/cliproxyapi"
touch "$TMP_DIR/config/proxy.yaml"
printf '%s\n' 'test-token' >"$TMP_DIR/config/token"
CLAUDEX_TEST_ENV=(
  "PATH=$MOCK_BIN:$PATH"
  "CLAUDE_BIN=$MOCK_BIN/claude"
  "CLIPROXYAPI_BIN=$MOCK_BIN/cliproxyapi"
  "CLAUDEX_PROXY_CONFIG=$TMP_DIR/config/proxy.yaml"
  "CLAUDEX_TOKEN_FILE=$TMP_DIR/config/token"
  "XDG_STATE_HOME=$XDG_STATE_HOME"
)

XHIGH_MOCK_BIN="$TMP_DIR/xhigh-mock-bin"
XHIGH_CALL_LOG="$TMP_DIR/xhigh-calls"
mkdir -p "$XHIGH_MOCK_BIN"
for program in claude cliproxyapi curl; do
  cat >"$XHIGH_MOCK_BIN/$program" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$(basename "$0")" >>"${XHIGH_CALL_LOG:?}"
exit 0
EOF
  chmod 755 "$XHIGH_MOCK_BIN/$program"
done
XHIGH_TEST_ENV=(
  "PATH=$XHIGH_MOCK_BIN:$PATH"
  "CLAUDE_BIN=$XHIGH_MOCK_BIN/claude"
  "CLIPROXYAPI_BIN=$XHIGH_MOCK_BIN/cliproxyapi"
  "CLAUDEX_PROXY_CONFIG=$TMP_DIR/config/proxy.yaml"
  "CLAUDEX_TOKEN_FILE=$TMP_DIR/config/token"
  "XHIGH_CALL_LOG=$XHIGH_CALL_LOG"
)
for invocation in \
  "CLAUDEX_EFFORT=xhigh $ROOT_DIR/bin/claudex --print xhigh-env" \
  "$ROOT_DIR/bin/claudex terra --effort xhigh --print xhigh-terra" \
  "$ROOT_DIR/bin/claudex --effort=xhigh --print xhigh-implicit" \
  "$ROOT_DIR/bin/claudex --effort --effort=xhigh --print xhigh-nested" \
  "$ROOT_DIR/bin/claudex luna --effort xhigh xhigh-luna" \
  "$ROOT_DIR/bin/claudex sol --effort=xhigh xhigh-sol" \
  "$ROOT_DIR/bin/claudex frontend --effort=xhigh xhigh-frontend" \
  "$ROOT_DIR/bin/claudex sol-review --effort xhigh"; do
  : >"$XHIGH_CALL_LOG"
  expect_fail env "${XHIGH_TEST_ENV[@]}" bash -c "$invocation"
  [[ ! -s "$XHIGH_CALL_LOG" ]] || fail "xhigh must fail before proxy or Claude invocation: $invocation"
done
for invocation in \
  "$ROOT_DIR/bin/claudex frontend --effort low frontend-override" \
  "$ROOT_DIR/bin/claudex frontend --model=gpt-5.6-sol frontend-override" \
  "$ROOT_DIR/bin/claudex frontend --agent claudex-sol frontend-override" \
  "$ROOT_DIR/bin/claudex --agent=claudex-frontend --model gpt-5.6-sol --effort low frontend-bypass" \
  "$ROOT_DIR/bin/claudex terra --agent claudex-frontend --model gpt-5.6-sol --effort low frontend-bypass"; do
  : >"$XHIGH_CALL_LOG"
  expect_fail env "${XHIGH_TEST_ENV[@]}" bash -c "$invocation"
  [[ ! -s "$XHIGH_CALL_LOG" ]] || fail "frontend overrides must fail before proxy or Claude invocation: $invocation"
done
PERMITTED_EFFORT_ARGS="$TMP_DIR/permitted-effort-args"
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" MOCK_CLAUDE_ARGS_LOG="$PERMITTED_EFFORT_ARGS" "$ROOT_DIR/bin/claudex" terra --effort medium --print 'permitted effort fixture' >/dev/null)
grep -Fxq 'medium' "$PERMITTED_EFFORT_ARGS" || fail 'non-xhigh effort arguments must pass through unchanged'
ROLE_OVERRIDE_ARGS="$TMP_DIR/role-override-args"
expect_fail env "${CLAUDEX_TEST_ENV[@]}" MOCK_CLAUDE_ARGS_LOG="$ROLE_OVERRIDE_ARGS" bash -c "cd '$REPO' && '$ROOT_DIR/bin/claudex' luna --effort low role-override"
[[ ! -e "$ROLE_OVERRIDE_ARGS" ]] || fail 'Luna effort must not be user-overridable'
expect_fail env "${CLAUDEX_TEST_ENV[@]}" MOCK_CLAUDE_ARGS_LOG="$ROLE_OVERRIDE_ARGS" bash -c "cd '$REPO' && '$ROOT_DIR/bin/claudex' sol --effort=high role-override"
[[ ! -e "$ROLE_OVERRIDE_ARGS" ]] || fail 'Sol advisory effort must not be user-overridable'

TELEMETRY_FILE="$XDG_STATE_HOME/claudex/telemetry/events.jsonl"
rm -rf "$XDG_STATE_HOME/claudex/telemetry"
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" "$ROOT_DIR/bin/claudex" luna 'disabled telemetry fixture' >/dev/null)
[[ ! -e "$TELEMETRY_FILE" ]] || fail 'telemetry must be disabled by default'

FRESH_STATE="$TMP_DIR/fresh-state"
rm -rf "$FRESH_STATE"
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" XDG_STATE_HOME="$FRESH_STATE" CLAUDEX_TELEMETRY=1 "$ROOT_DIR/bin/claudex" luna 'fresh telemetry state' >/dev/null)
FRESH_TELEMETRY_FILE="$FRESH_STATE/claudex/telemetry/events.jsonl"
[[ -f "$FRESH_TELEMETRY_FILE" ]] || fail 'enabled telemetry must initialize absent XDG state'
[[ "$(stat -f '%Lp' "$FRESH_STATE/claudex/telemetry")" == 700 ]] || fail 'telemetry directory must be private'
[[ "$(stat -f '%Lp' "$FRESH_TELEMETRY_FILE")" == 600 ]] || fail 'telemetry file must be private'

ARGS_DISABLED="$TMP_DIR/telemetry-disabled-args"
ARGS_ENABLED="$TMP_DIR/telemetry-enabled-args"
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" MOCK_CLAUDE_ARGS_LOG="$ARGS_DISABLED" "$ROOT_DIR/bin/claudex" luna 'argument sentinel' >/dev/null)
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" CLAUDEX_TELEMETRY=1 MOCK_CLAUDE_ARGS_LOG="$ARGS_ENABLED" "$ROOT_DIR/bin/claudex" luna 'argument sentinel' >/dev/null)
cmp -s "$ARGS_DISABLED" "$ARGS_ENABLED" || fail 'telemetry must preserve Claude arguments'

TELEMETRY_STDERR="$TMP_DIR/telemetry-stderr"
TELEMETRY_STDOUT="$(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" \
  CLAUDEX_TELEMETRY=1 \
  CLAUDEX_LUNA_MODEL='custom-model-secret-42' \
  CLAUDEX_AUTOCOMPACT='1secret-valuek' \
  CLAUDEX_BASE_URL='http://secret.example.invalid' \
  MOCK_CLAUDE_STDOUT='telemetry stdout sentinel' \
  MOCK_CLAUDE_STDERR='telemetry stderr sentinel' \
  "$ROOT_DIR/bin/claudex" luna 'telemetry prompt secret' 2>"$TELEMETRY_STDERR")"
[[ "$TELEMETRY_STDOUT" == 'telemetry stdout sentinel' ]] || fail 'telemetry must preserve Claude stdout'
grep -Fxq 'telemetry stderr sentinel' "$TELEMETRY_STDERR" || fail 'telemetry must preserve Claude stderr'
python3 - "$TELEMETRY_FILE" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
records = [json.loads(line) for line in path.read_text().splitlines()]
assert {record['event'] for record in records} >= {'proxy_ready', 'launch_completed'}, records
launch = next(record for record in reversed(records) if record['event'] == 'launch_completed')
assert launch['mode'] == 'luna', launch
assert launch['route'] == 'custom', launch
assert launch['effort'] == 'high', launch
assert launch['autocompact'] == 'custom', launch
assert launch['launcher_revision'] == 2, launch
assert launch['exit_code'] == 0 and launch['elapsed_ms'] >= 0, launch
allowed = {'format', 'event', 'recorded_at', 'invocation_id', 'launcher_revision', 'mode', 'route', 'effort', 'autocompact', 'proxy_start_attempted', 'proxy_ready', 'proxy_probes', 'elapsed_ms', 'exit_code', 'sol_review_verdict', 'receipt_status'}
assert all(set(record) == allowed for record in records), records
text = path.read_text()
for forbidden in ('telemetry prompt secret', 'custom-model-secret-42', '1secret-valuek', 'secret.example.invalid', 'test-token', 'telemetry stdout sentinel', 'telemetry stderr sentinel'):
    assert forbidden not in text, forbidden
PY
expect_fail env "${CLAUDEX_TEST_ENV[@]}" CLAUDEX_TELEMETRY=1 MOCK_CLAUDE_EXIT=7 bash -c "cd '$REPO' && '$ROOT_DIR/bin/claudex' luna nonzero"
python3 - "$TELEMETRY_FILE" <<'PY'
import json, sys
launch = next(record for record in reversed([json.loads(line) for line in open(sys.argv[1])]) if record['event'] == 'launch_completed')
assert launch['exit_code'] == 7, launch
PY
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" CLAUDEX_TELEMETRY=1 "$ROOT_DIR/bin/claudex" terra --effort medium --print 'telemetry effort fixture' >/dev/null)
python3 - "$TELEMETRY_FILE" <<'PY'
import json, sys
launch = next(record for record in reversed([json.loads(line) for line in open(sys.argv[1])]) if record['event'] == 'launch_completed')
assert launch['mode'] == 'terra' and launch['effort'] == 'medium', launch
PY

LOCK_READY="$TMP_DIR/telemetry-lock-ready"
python3 - "$XDG_STATE_HOME/claudex/telemetry/.lock" "$LOCK_READY" <<'PY' &
import fcntl, pathlib, sys, time
lock_path, ready_path = map(pathlib.Path, sys.argv[1:])
with lock_path.open('a+') as handle:
    fcntl.flock(handle, fcntl.LOCK_EX)
    ready_path.touch()
    time.sleep(2)
PY
LOCK_PID=$!
while [[ ! -e "$LOCK_READY" ]]; do sleep 0.01; done
RECORDS_BEFORE="$(wc -l <"$TELEMETRY_FILE")"
SECONDS=0
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" CLAUDEX_TELEMETRY=1 "$ROOT_DIR/bin/claudex" luna 'held lock fixture' >/dev/null)
[[ "$SECONDS" -lt 2 ]] || fail 'held telemetry lock must not delay launch'
wait "$LOCK_PID"
[[ "$(wc -l <"$TELEMETRY_FILE")" == "$RECORDS_BEFORE" ]] || fail 'held telemetry lock must drop events'

python3 - "$TELEMETRY_FILE" <<'PY'
import json, sys
path = sys.argv[1]
payload = 'x' * 1_048_000
with open(path, 'w') as handle:
    for _ in range(5):
        handle.write(json.dumps({'fixture': payload}) + '\n')
PY
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" CLAUDEX_TELEMETRY=1 "$ROOT_DIR/bin/claudex" luna 'cap fixture' >/dev/null)
[[ "$(stat -f '%z' "$TELEMETRY_FILE")" -le 5242880 ]] || fail 'telemetry must enforce its size cap'
python3 - "$TELEMETRY_FILE" <<'PY'
import json, sys
for line in open(sys.argv[1]):
    json.loads(line)
PY

SOL_ADVISORY_ARGS="$TMP_DIR/sol-advisory-args"
FRONTEND_ARGS="$TMP_DIR/frontend-args"
SOL_REVIEW_ARGS="$TMP_DIR/sol-review-args"
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" MOCK_CLAUDE_ARGS_LOG="$SOL_ADVISORY_ARGS" "$ROOT_DIR/bin/claudex" sol 'advisory fixture' >/dev/null)
grep -Fxq -- '--agent' "$SOL_ADVISORY_ARGS" || fail 'Sol advisory must select a custom agent'
grep -Fxq 'claudex-sol' "$SOL_ADVISORY_ARGS" || fail 'Sol advisory must select claudex-sol'
grep -Fxq 'medium' "$SOL_ADVISORY_ARGS" || fail 'Sol advisory must use medium effort'
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" CLAUDEX_EFFORT=low MOCK_CLAUDE_ARGS_LOG="$FRONTEND_ARGS" "$ROOT_DIR/bin/claudex" frontend 'frontend implementation fixture' >/dev/null)
grep -Fxq -- '--agent' "$FRONTEND_ARGS" || fail 'Frontend must select a custom agent'
grep -Fxq 'claudex-frontend' "$FRONTEND_ARGS" || fail 'Frontend must select claudex-frontend'
grep -Fxq -- '--model' "$FRONTEND_ARGS" || fail 'Frontend must select its fixed model'
grep -Fxq 'gpt-5.6-terra' "$FRONTEND_ARGS" || fail 'Frontend must select Terra'
grep -Fxq 'high' "$FRONTEND_ARGS" || fail 'Frontend must retain high effort despite CLAUDEX_EFFORT'
grep -Fxq -- '--permission-mode' "$FRONTEND_ARGS" || fail 'Frontend must request implementation permissions'
grep -Fxq 'default' "$FRONTEND_ARGS" || fail 'Frontend must use default permission mode'
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" MOCK_CLAUDE_ARGS_LOG="$SOL_REVIEW_ARGS" "$ROOT_DIR/bin/claudex" sol-review >/dev/null)
grep -Fxq -- '--agent' "$SOL_REVIEW_ARGS" || fail 'Sol Review must select a custom agent'
grep -Fxq 'claudex-sol-review' "$SOL_REVIEW_ARGS" || fail 'Sol Review must select claudex-sol-review'
grep -Fxq 'medium' "$SOL_REVIEW_ARGS" || fail 'Sol Review must use medium effort'

(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" CLAUDEX_TELEMETRY=1 "$ROOT_DIR/bin/claudex" frontend 'frontend telemetry secret' >/dev/null)
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" CLAUDEX_TELEMETRY=1 "$ROOT_DIR/bin/claudex" sol 'Sol telemetry fixture' >/dev/null)
(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" CLAUDEX_TELEMETRY=1 "$ROOT_DIR/bin/claudex" sol-review >/dev/null)
python3 - "$TELEMETRY_FILE" <<'PY'
import json, sys
records = [json.loads(line) for line in open(sys.argv[1])]
frontend = next(record for record in reversed(records) if record['event'] == 'launch_completed' and record['mode'] == 'frontend')
sol = next(record for record in reversed(records) if record['event'] == 'launch_completed' and record['mode'] == 'sol')
review = next(record for record in reversed(records) if record['event'] == 'launch_completed' and record['mode'] == 'sol-review')
assert frontend['route'] == 'frontend' and frontend['effort'] == 'high', frontend
assert sol['effort'] == 'medium', sol
assert review['effort'] == 'medium', review
assert 'frontend telemetry secret' not in open(sys.argv[1]).read()
PY

(cd "$REPO" && env "${CLAUDEX_TEST_ENV[@]}" "$ROOT_DIR/bin/claudex" sol-review >/dev/null)
[[ "$(git -C "$REPO" worktree list --porcelain | grep -c '^worktree ')" -eq 1 ]] || fail 'successful Sol review must clean its temporary worktree'
[[ -z "$(find "$XDG_STATE_HOME/claudex/tmp" -mindepth 1 -print -quit)" ]] || fail 'successful Sol review must clean temporary review files'

RECEIPT_PATH="$XDG_STATE_HOME/claudex/reviews/$REVIEWED_TREE.json"
rm -f "$RECEIPT_PATH"
expect_fail env "${CLAUDEX_TEST_ENV[@]}" MOCK_SOL_VERDICT=CHANGES_REQUIRED bash -c "cd '$REPO' && '$ROOT_DIR/bin/claudex' sol-review"
[[ ! -e "$RECEIPT_PATH" ]] || fail 'failed Sol review must not save an approval receipt'
[[ "$(git -C "$REPO" worktree list --porcelain | grep -c '^worktree ')" -eq 1 ]] || fail 'failed Sol review must clean its temporary worktree'
[[ -z "$(find "$XDG_STATE_HOME/claudex/tmp" -mindepth 1 -print -quit)" ]] || fail 'failed Sol review must clean temporary review files'

POLICY_REPO="$TMP_DIR/policy-repo"
git -C "$TMP_DIR" init -q policy-repo
git -C "$POLICY_REPO" config user.email test@example.invalid
git -C "$POLICY_REPO" config user.name test
mkdir -p "$POLICY_REPO/.claudex"
printf '%s\n' 'true' >"$POLICY_REPO/.claudex/verify-commands"
git -C "$POLICY_REPO" add .claudex/verify-commands
[[ "$(cd "$POLICY_REPO" && "$GATE" classify)" == "sensitive" ]] || fail 'verification policy changes must be sensitive'

touch "$REPO/auth/rotation.ts"
git -C "$REPO" add auth/rotation.ts
expect_fail bash -c "cd '$REPO' && '$GATE' check"

echo 'PASS: Claudex workflow tests'
