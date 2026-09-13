#!/usr/bin/env bash
# Integration test for scripts/sync-upstream.sh (story 001, sub-task 6.1).
#
# Contract under test (design.md §5, R5.1-R5.4):
#   sync-upstream.sh --repo <path> [--to <ref>] [--build-cmd <cmd>]
#   - fetches upstream, tags zeo-pre-sync, rebases branch `zeo` (rerere on),
#     runs the build gate, records the last-good SHA in <repo>/.git/zeo-last-good.
#   - conflict  -> rebase aborted, branch unchanged, non-zero exit, message
#                  naming the conflict.
#   - gate fail -> branch restored to pre-sync state, non-zero exit.
#   - any outcome -> no zeo-pre-sync tag and no rebase state left behind.
#
# Runner: bash tests/sync-upstream.test.sh   (from the workspace root)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/sync-upstream.sh"

FAILURES=0
CHECKS=0

pass() { CHECKS=$((CHECKS + 1)); printf 'ok   %s\n' "$1"; }
fail() { CHECKS=$((CHECKS + 1)); FAILURES=$((FAILURES + 1)); printf 'FAIL %s\n' "$1" >&2; }

assert_eq() { # assert_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected '$2', got '$3')"; fi
}

assert_zero() { # assert_zero <label> <rc>
  if [ "$2" -eq 0 ]; then pass "$1"; else fail "$1 (exit code $2, expected 0)"; fi
}

assert_nonzero() { # assert_nonzero <label> <rc>
  if [ "$2" -ne 0 ]; then pass "$1"; else fail "$1 (exit code 0, expected non-zero)"; fi
}

if [ ! -f "$SCRIPT" ]; then
  fail "sync script exists at scripts/sync-upstream.sh (not found: $SCRIPT)"
  printf '\n%d checks, %d failures\n' "$CHECKS" "$FAILURES" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Isolate git from user/system configuration.
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
export GIT_CONFIG_SYSTEM=/dev/null
git config --file "$GIT_CONFIG_GLOBAL" user.name "sync-test"
git config --file "$GIT_CONFIG_GLOBAL" user.email "sync-test@example.invalid"
git config --file "$GIT_CONFIG_GLOBAL" commit.gpgsign false
git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main

# make_fixtures <name> <clean|conflict>
# Creates $TMP/<name>-upstream (remote) and $TMP/<name>-fork (clone with
# remote `upstream` and branch `zeo` carrying one divergent commit), then
# advances the upstream AFTER the clone so the script must really fetch.
# Exports: FIX_UP, FIX_FORK, FIX_PRE_SHA (zeo tip before sync),
#          FIX_UP_TIP (new upstream tip the sync must land on).
make_fixtures() {
  local name="$1" mode="$2"
  FIX_UP="$TMP/$name-upstream"
  FIX_FORK="$TMP/$name-fork"

  git init -q -b main "$FIX_UP"
  printf 'line1\nline2\nline3\n' >"$FIX_UP/file.txt"
  git -C "$FIX_UP" add file.txt
  git -C "$FIX_UP" commit -qm "base"

  git clone -q "$FIX_UP" "$FIX_FORK"
  git -C "$FIX_FORK" remote rename origin upstream
  git -C "$FIX_FORK" checkout -qb zeo

  if [ "$mode" = "conflict" ]; then
    printf 'fork-line1\nline2\nline3\n' >"$FIX_FORK/file.txt"
    git -C "$FIX_FORK" commit -qam "fork: change line1"
  else
    printf 'fork feature\n' >"$FIX_FORK/fork.txt"
    git -C "$FIX_FORK" add fork.txt
    git -C "$FIX_FORK" commit -qm "fork: add feature"
  fi
  FIX_PRE_SHA="$(git -C "$FIX_FORK" rev-parse zeo)"

  # Advance upstream after the clone (stale remote-tracking ref in the fork).
  if [ "$mode" = "conflict" ]; then
    printf 'upstream-line1\nline2\nline3\n' >"$FIX_UP/file.txt"
    git -C "$FIX_UP" commit -qam "upstream: change line1"
  else
    printf 'upstream work\n' >"$FIX_UP/upstream.txt"
    git -C "$FIX_UP" add upstream.txt
    git -C "$FIX_UP" commit -qm "upstream: advance"
  fi
  FIX_UP_TIP="$(git -C "$FIX_UP" rev-parse main)"
}

# check_no_residue <label-prefix> <fork-path>
# R5.4: no temporary tags and no rebase state left behind, in any outcome.
check_no_residue() {
  local label="$1" fork="$2"
  assert_eq "$label: no zeo-pre-sync tag left behind" \
    "" "$(git -C "$fork" tag -l 'zeo-pre-sync*')"
  if [ -d "$fork/.git/rebase-merge" ] || [ -d "$fork/.git/rebase-apply" ]; then
    fail "$label: no rebase state left behind"
  else
    pass "$label: no rebase state left behind"
  fi
  assert_eq "$label: working tree clean" \
    "" "$(git -C "$fork" status --porcelain)"
}

# --- Scenario 1: clean rebase + passing build gate (R5.1) -------------------
make_fixtures s1 clean
rc=0
bash "$SCRIPT" --repo "$FIX_FORK" --to upstream/main --build-cmd true \
  >"$TMP/s1.log" 2>&1 || rc=$?
assert_zero "s1: exits 0 on clean sync" "$rc"
new_tip="$(git -C "$FIX_FORK" rev-parse zeo)"
if [ "$new_tip" != "$FIX_PRE_SHA" ]; then
  pass "s1: branch zeo moved off the pre-sync SHA"
else
  fail "s1: branch zeo moved off the pre-sync SHA (still at $FIX_PRE_SHA)"
fi
if git -C "$FIX_FORK" merge-base --is-ancestor "$FIX_UP_TIP" zeo; then
  pass "s1: new upstream tip is an ancestor of zeo (rebased onto it)"
else
  fail "s1: new upstream tip is an ancestor of zeo (script must fetch + rebase)"
fi
if git -C "$FIX_FORK" log --format=%s zeo | grep -q '^fork: add feature$'; then
  pass "s1: fork commit survives the rebase"
else
  fail "s1: fork commit survives the rebase"
fi
if [ -f "$FIX_FORK/.git/zeo-last-good" ]; then
  assert_eq "s1: last-good marker records the new zeo tip" \
    "$new_tip" "$(cat "$FIX_FORK/.git/zeo-last-good")"
else
  fail "s1: last-good marker records the new zeo tip (.git/zeo-last-good missing)"
fi
check_no_residue "s1" "$FIX_FORK"

# --- Scenario 2: rebase conflict -> abort, branch pinned (R5.2) -------------
make_fixtures s2 conflict
rc=0
bash "$SCRIPT" --repo "$FIX_FORK" --to upstream/main --build-cmd true \
  >"$TMP/s2.log" 2>&1 || rc=$?
assert_nonzero "s2: exits non-zero on rebase conflict" "$rc"
assert_eq "s2: branch zeo unchanged at last-good (pre-sync) SHA" \
  "$FIX_PRE_SHA" "$(git -C "$FIX_FORK" rev-parse zeo)"
if grep -qi 'conflict' "$TMP/s2.log"; then
  pass "s2: failure message names the conflict"
else
  fail "s2: failure message names the conflict (no 'conflict' in output)"
fi
check_no_residue "s2" "$FIX_FORK"

# --- Scenario 3: build gate failure -> restore pre-sync state (R5.3) --------
make_fixtures s3 clean
rc=0
bash "$SCRIPT" --repo "$FIX_FORK" --to upstream/main --build-cmd false \
  >"$TMP/s3.log" 2>&1 || rc=$?
assert_nonzero "s3: exits non-zero when the build gate fails" "$rc"
assert_eq "s3: branch zeo restored to the pre-sync SHA" \
  "$FIX_PRE_SHA" "$(git -C "$FIX_FORK" rev-parse zeo)"
check_no_residue "s3" "$FIX_FORK"

# --- Summary -----------------------------------------------------------------
printf '\n%d checks, %d failures\n' "$CHECKS" "$FAILURES"
if [ "$FAILURES" -ne 0 ]; then
  exit 1
fi
