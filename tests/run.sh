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

bash -n "$ROOT_DIR/bin/claudex" "$ROOT_DIR/bin/claudex-review-receipt" "$ROOT_DIR/install.sh"
test -f "$ROOT_DIR/agents/claudex-terra.md"
test -f "$ROOT_DIR/agents/claudex-luna.md"
test -f "$ROOT_DIR/agents/claudex-sol.md"
test -f "$ROOT_DIR/agents/claudex-sol-review.md"
test -f "$ROOT_DIR/agents/claudex-frontend.md"
test -f "$ROOT_DIR/prompts/terra-routing.md"
grep -Fq 'model: gpt-5.5' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Coordinator must use GPT-5.5'
grep -Fq 'effort: medium' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Coordinator must use medium effort'
grep -Fq 'effort: high' "$ROOT_DIR/agents/claudex-luna.md" || fail 'Luna must remain high effort'
grep -Fq 'effort: medium' "$ROOT_DIR/agents/claudex-sol.md" || fail 'Sol advisory must use medium effort'
grep -Fq 'effort: medium' "$ROOT_DIR/agents/claudex-sol-review.md" || fail 'Sol Review must use medium effort'
grep -Fq 'model: gpt-5.5' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must use GPT-5.5'
grep -Fq 'effort: high' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must use high effort'
grep -Fq 'permissionMode: default' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must have implementation permissions'
grep -Fq 'Do not change backend logic, schemas, contracts, authentication or authorization' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must retain its narrow write boundary'
grep -Fq 'Do not monitor, infer lifecycle state, poll, resume, restart, steer, or inject continuation.' "$ROOT_DIR/agents/claudex-frontend.md" || fail 'Frontend must not introduce session supervision'
grep -Fq 'medium effort for bounded architecture alternatives' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must define Sol as a medium-effort advisory'
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
grep -Fq 'medium effort for bounded architecture alternatives' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must define Sol as a medium-effort advisory'
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
cat >"$INSTALL_MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod 755 "$INSTALL_MOCK_BIN/claude" "$INSTALL_MOCK_BIN/cliproxyapi" "$INSTALL_MOCK_BIN/curl"
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
printf '%s\n' 'stale prompt' >"$INSTALLED_PROMPT"
printf '%s\n' 'stale agent' >"$INSTALLED_AGENT_HOME/claudex-sol-review.md"
env \
  HOME="$INSTALL_HOME" \
  XDG_CONFIG_HOME="$INSTALL_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login >/dev/null
cmp -s "$ROOT_DIR/prompts/terra-routing.md" "$INSTALLED_PROMPT" || fail 'install.sh must refresh the installed routing prompt on reinstall'
for agent in claudex-terra claudex-luna claudex-frontend claudex-sol claudex-sol-review; do
  cmp -s "$ROOT_DIR/agents/$agent.md" "$INSTALLED_AGENT_HOME/$agent.md" || fail "install.sh must refresh $agent on reinstall"
done
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
grep -Fxq 'gpt-5.5' "$FRONTEND_ARGS" || fail 'Frontend must select GPT-5.5'
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
