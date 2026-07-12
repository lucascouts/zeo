#!/usr/bin/env bash
# Integration test for scripts/shot.sh (story 002, sub-task 1.1).
#
# Contract under test (design.md §9 "Screenshot harness", R5.1-R5.2):
#   shot.sh --label <before|after> --surface <name>
#           [--bin <path>]      (default: target/release/zeo)
#           [--out-dir <path>]  (default: .epic/stories/002-visual-identity/shots)
#           [--settle <secs>]   (how long to wait for the window; default > 0)
#
#   - runs TWO passes per invocation, one per appearance (light and dark), and
#     emits <out-dir>/<label>/<surface>-light.png and <surface>-dark.png.
#   - each pass launches the binary against a THROWAWAY config dir
#     (XDG_CONFIG_HOME under a temp dir — never the user's ~/.config), whose
#     settings.json pins the appearance for that pass.
#   - capture is `grim` (full output) + `magick` crop against FIXED coordinates.
#     `slurp` is absent on this host and MUST NEVER be invoked (R5.2): an
#     interactive region would make the pairs non-comparable.
#   - missing `grim`      -> exit non-zero naming the tool, emit NO png at all
#                            (never a zero-byte file).
#   - failed launch       -> exit non-zero naming the step, leave no partial output.
#   - bad/missing args    -> exit non-zero.
#
# Runner: bash tests/shot.test.sh   (from the workspace root)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/shot.sh"

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

assert_file_nonempty() { # assert_file_nonempty <label> <path>
  if [ -s "$2" ]; then pass "$1"; else fail "$1 (missing or zero-byte: $2)"; fi
}

assert_no_png() { # assert_no_png <label> <dir>
  local found
  found="$(find "$2" -name '*.png' 2>/dev/null | head -1 || true)"
  if [ -z "$found" ]; then pass "$1"; else fail "$1 (found: $found)"; fi
}

if [ ! -f "$SCRIPT" ]; then
  fail "shot script exists at scripts/shot.sh (not found: $SCRIPT)"
  printf '\n%d checks, %d failures\n' "$CHECKS" "$FAILURES" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# make_shims <mode>
#   mode `full`    — grim, magick and slurp are all on PATH.
#   mode `no-grim` — grim is absent; magick and slurp are present.
#
# The stubs record every invocation so the assertions can inspect what the
# script actually did, and `slurp` is a TRIPWIRE: it fails loudly if called,
# because `slurp` is absent on the real host (R5.2) and a script that reaches
# for it would work here and break there.
#
# Exports: SHIM (dir to prepend to PATH), BIN_LOG, GRIM_LOG, MAGICK_LOG, SLURP_LOG.
make_shims() {
  local mode="$1"
  SHIM="$TMP/$mode/bin"
  BIN_LOG="$TMP/$mode/bin.log"
  GRIM_LOG="$TMP/$mode/grim.log"
  MAGICK_LOG="$TMP/$mode/magick.log"
  SLURP_LOG="$TMP/$mode/slurp.log"
  mkdir -p "$SHIM"
  : >"$BIN_LOG"
  : >"$GRIM_LOG"
  : >"$MAGICK_LOG"
  : >"$SLURP_LOG"

  if [ "$mode" != "no-grim" ]; then
    # `grim <file>` writes a full-output capture. The stub writes real bytes so
    # that a zero-byte result can only come from the script, never from here.
    cat >"$SHIM/grim" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$GRIM_LOG"
out="\${*: -1}"
printf 'fake-full-output-capture' >"\$out"
EOF
    chmod +x "$SHIM/grim"
  fi

  # `magick <src> -crop WxH+X+Y +repage <dst>`: the crop must be FIXED, which is
  # the whole reason the fixture is pinned in the script (R5.2).
  cat >"$SHIM/magick" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$MAGICK_LOG"
src="\$1"
dst="\${*: -1}"
if [ ! -s "\$src" ]; then
  printf 'magick: refusing to crop an empty source: %s\n' "\$src" >&2
  exit 1
fi
cp "\$src" "\$dst"
EOF
  chmod +x "$SHIM/magick"

  cat >"$SHIM/slurp" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$SLURP_LOG"
printf 'slurp: this host has no slurp; the harness must never call it (R5.2)\n' >&2
exit 1
EOF
  chmod +x "$SHIM/slurp"
}

# make_bin <path> <exit-code> <log>
# A stub "zeo": records the config dir it was launched against, plus the
# settings.json it found there, then exits with the requested code.
make_bin() {
  local path="$1" rc="$2" log="$3"
  cat >"$path" <<EOF
#!/usr/bin/env bash
set -uo pipefail
{
  printf 'launch args=%s\n' "\$*"
  printf 'launch XDG_CONFIG_HOME=%s\n' "\${XDG_CONFIG_HOME:-<unset>}"
  if [ -f "\${XDG_CONFIG_HOME:-/nonexistent}/zeo/settings.json" ]; then
    printf 'launch settings=%s\n' "\$(tr -d ' \n' <"\${XDG_CONFIG_HOME}/zeo/settings.json")"
  else
    printf 'launch settings=<none>\n'
  fi
} >>"$log"
exit $rc
EOF
  chmod +x "$path"
}

run_shot() { # run_shot <shim-dir> <args...> -> sets `rc` and writes $TMP/last.log
  local shim="$1"
  shift
  rc=0
  PATH="$shim:$PATH" bash "$SCRIPT" "$@" >"$TMP/last.log" 2>&1 || rc=$?
}

# --- Scenario 1: happy path — both appearances, fixed crop, throwaway config --
make_shims full
BIN="$TMP/zeo-ok"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s1"

run_shot "$SHIM" --label before --surface command-palette \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_zero "s1: exits 0 on a successful capture" "$rc"

assert_file_nonempty "s1: emits <label>/<surface>-light.png, non-zero bytes" \
  "$OUT/before/command-palette-light.png"
assert_file_nonempty "s1: emits <label>/<surface>-dark.png, non-zero bytes" \
  "$OUT/before/command-palette-dark.png"

assert_eq "s1: the binary is launched exactly twice (one pass per appearance)" \
  "2" "$(grep -c '^launch args=' "$BIN_LOG" || true)"
assert_eq "s1: grim captures exactly twice" \
  "2" "$(grep -c . "$GRIM_LOG" || true)"

# Both appearances really are forced — not the same pass run twice.
if grep -q '"mode":"light"' "$BIN_LOG" && grep -q '"mode":"dark"' "$BIN_LOG"; then
  pass "s1: each pass pins its appearance in the throwaway settings.json (light and dark)"
else
  fail "s1: each pass pins its appearance in the throwaway settings.json (light and dark) (got: $(grep '^launch settings=' "$BIN_LOG" | tr '\n' ' '))"
fi

# The user's real profile must never be touched (a capture that inherits the
# user's settings is not a fixture — and it can mutate their config).
if grep -q "^launch XDG_CONFIG_HOME=${HOME}/.config$" "$BIN_LOG"; then
  fail "s1: launches against a throwaway config dir, never \$HOME/.config"
elif grep -q '^launch XDG_CONFIG_HOME=<unset>$' "$BIN_LOG"; then
  fail "s1: launches against a throwaway config dir (XDG_CONFIG_HOME was not set at all)"
else
  pass "s1: launches against a throwaway config dir, never \$HOME/.config"
fi

# R5.2: no slurp anywhere, and the crop geometry is fixed in the script.
assert_eq "s1: never invokes slurp (absent on this host — fixed crop instead)" \
  "" "$(cat "$SLURP_LOG")"
if grep -qE -- '-crop +[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' "$MAGICK_LOG"; then
  pass "s1: crops against fixed WxH+X+Y coordinates"
else
  fail "s1: crops against fixed WxH+X+Y coordinates (got: $(tr '\n' ' ' <"$MAGICK_LOG"))"
fi

# --- Scenario 2: `grim` missing -> loud failure, never a zero-byte PNG (R5.2) --
make_shims no-grim
BIN="$TMP/zeo-ok2"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s2"

# Shadow the real grim, if the host has one: the script must detect its absence
# from *its own* lookup, so the shim dir must be the only PATH entry that counts.
run_shot "$SHIM" --label before --surface popover \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s2: exits non-zero when grim is unavailable" "$rc"
if grep -qi 'grim' "$TMP/last.log"; then
  pass "s2: the failure message names grim"
else
  fail "s2: the failure message names grim (got: $(head -3 "$TMP/last.log" | tr '\n' ' '))"
fi
assert_no_png "s2: emits no PNG at all — not even a zero-byte one" "$OUT"

# --- Scenario 3: launch failure -> non-zero, no partial output ---------------
make_shims full
BIN="$TMP/zeo-broken"
make_bin "$BIN" 1 "$BIN_LOG"
OUT="$TMP/shots-s3"

run_shot "$SHIM" --label after --surface modal \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s3: exits non-zero when the binary fails to launch" "$rc"
if grep -qiE 'launch|start' "$TMP/last.log"; then
  pass "s3: the failure message names the step that failed"
else
  fail "s3: the failure message names the step that failed (got: $(head -3 "$TMP/last.log" | tr '\n' ' '))"
fi
assert_no_png "s3: leaves no partial output behind" "$OUT"

# --- Scenario 4: argument validation ----------------------------------------
make_shims full
BIN="$TMP/zeo-ok4"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s4"

run_shot "$SHIM" --surface modal --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s4: exits non-zero when --label is missing" "$rc"

run_shot "$SHIM" --label before --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s4: exits non-zero when --surface is missing" "$rc"

run_shot "$SHIM" --label sideways --surface modal --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s4: exits non-zero on a --label outside {before,after}" "$rc"

assert_no_png "s4: writes nothing when the arguments are rejected" "$OUT"

# --- Summary -----------------------------------------------------------------
printf '\n%d checks, %d failures\n' "$CHECKS" "$FAILURES"
if [ "$FAILURES" -ne 0 ]; then
  exit 1
fi
