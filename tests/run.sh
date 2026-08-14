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
test -f "$ROOT_DIR/prompts/terra-routing.md"
grep -Fq 'independent Sol review before Terra approves the plan or starts implementation' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require an independent Sol review before consequential implementation'
grep -Fq 'another independent Sol review before Terra treats the change as complete or merge-ready' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must require an independent Sol review before consequential completion'
grep -Fq 'at most three concurrently' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must cap concurrent subagents at three'
grep -Fq 'A generic planning agent is not a substitute for Sol review.' "$ROOT_DIR/prompts/terra-routing.md" || fail 'routing prompt must reject generic planning as a Sol substitute'
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
grep -Fq 'before you approve the plan or start implementation' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must require Sol review before consequential implementation'
grep -Fq 'before you treat the change as complete or merge-ready' "$ROOT_DIR/agents/claudex-terra.md" || fail 'Terra agent must require Sol review before consequential completion'

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
cmp -s "$ROOT_DIR/prompts/terra-routing.md" "$INSTALLED_PROMPT" || fail 'install.sh must install the current routing prompt'
printf '%s\n' 'stale prompt' >"$INSTALLED_PROMPT"
env \
  HOME="$INSTALL_HOME" \
  XDG_CONFIG_HOME="$INSTALL_XDG" \
  PATH="$INSTALL_MOCK_BIN:$PATH" \
  SHELL=/bin/zsh \
  CLAUDEX_INSTALL_MODE=configure-only \
  "$ROOT_DIR/install.sh" --skip-login >/dev/null
cmp -s "$ROOT_DIR/prompts/terra-routing.md" "$INSTALLED_PROMPT" || fail 'install.sh must refresh the installed routing prompt on reinstall'
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
printf '{"verdict":"%s","summary":"mock review","findings":[],"uncertainties":[]}\n' "${MOCK_SOL_VERDICT:-PASS}"
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
