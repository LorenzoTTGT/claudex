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
