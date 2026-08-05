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

export XDG_STATE_HOME="$TMP_DIR/state"
[[ "$(cd "$REPO" && "$GATE" classify)" == "sensitive" ]] || fail 'expected sensitive staged change'
expect_fail bash -c "cd '$REPO' && '$GATE' check"

REVIEW="$TMP_DIR/review.json"
printf '%s\n' '{"verdict":"PASS","summary":"reviewed","findings":[],"uncertainties":[]}' >"$REVIEW"
(cd "$REPO" && "$GATE" write "$REVIEW" >/dev/null && "$GATE" check >/dev/null)

touch "$REPO/auth/rotation.ts"
git -C "$REPO" add auth/rotation.ts
expect_fail bash -c "cd '$REPO' && '$GATE' check"

echo 'PASS: Claudex workflow tests'
