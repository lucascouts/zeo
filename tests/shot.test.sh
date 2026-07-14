#!/usr/bin/env bash
# Integration test for scripts/shot.sh (story 002, sub-tasks 1.1 and 1.3).
#
# Contract under test (design.md §9 "Screenshot harness", R5.1-R5.2):
#
#   shot.sh --label <before|after> --surface <name>
#           [--bin <path>] [--out-dir <path>] [--settle <secs>]
#           [--keys <chord>]... [--theme-light <name>] [--theme-dark <name>]
#
#   - runs TWO passes per invocation, one per appearance (light and dark), and
#     emits <out-dir>/<label>/<surface>-light.png and <surface>-dark.png.
#   - the default out-dir is under `docs/visual/`, NOT under `.epic/` — the latter
#     is the first line of the workspace .gitignore, so evidence written there could
#     never be committed at all.
#   - each pass launches the binary against a THROWAWAY config dir (XDG_CONFIG_HOME
#     under a temp dir — never the user's ~/.config), whose settings.json pins the
#     appearance AND the theme names for that pass.
#   - capture is `spectacle -a -b -n -o <file>`: the ACTIVE WINDOW, through KWin's
#     own screenshot service. There is NO crop — a window-scoped capture cannot
#     drift with the screen resolution or the panel layout, which is exactly what a
#     fixed full-screen crop box does.
#   - `grim` must NEVER be invoked: KWin does not implement `wlr-screencopy`, so grim
#     cannot capture on this host at all (`grim -g '0,0 1x1' out.png` -> "compositor
#     doesn't support the screen capture protocol", exit 1, no file).
#   - `slurp` must NEVER be invoked (R5.2): an interactive region would make the
#     before/after pairs non-comparable.
#   - missing `spectacle` -> exit non-zero naming the tool, emit NO png at all (never
#     a zero-byte file), and never launch the binary.
#   - failed launch       -> exit non-zero naming the step, leave no partial output.
#   - failed capture      -> exit non-zero, no partial output, and NO STRAY WINDOW.
#   - a driven surface (--keys) whose input backend is unusable -> exit non-zero
#     BEFORE launching anything.
#   - the two passes must be diffable (R5.1): same geometry, or nothing is published.
#   - bad/missing args    -> exit non-zero.
#
# HERMETIC BY CONSTRUCTION. The script under test runs with PATH set to a shim dir
# and NOTHING ELSE, so it can only reach the stubs installed here. It never captures
# a real screen, never launches a real binary, and needs no desktop. (The one real
# end-to-end capture is a separate, human-supervised step: `spectacle -a` grabs the
# ACTIVE window, so a real run here would seize the operator's live desktop.)
#
# Runner: bash tests/shot.test.sh

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

assert_file_empty() { # assert_file_empty <label> <path>
  if [ ! -s "$2" ]; then pass "$1"; else fail "$1 (expected nothing, got: $(tr '\n' '|' <"$2"))"; fi
}

assert_no_png() { # assert_no_png <label> <dir>
  local found
  found="$(find "$2" -name '*.png' 2>/dev/null | head -1 || true)"
  if [ -z "$found" ]; then pass "$1"; else fail "$1 (found: $found)"; fi
}

assert_log_matches() { # assert_log_matches <label> <extended-regex> <file>
  # `--` so a pattern that opens with `-` is a pattern, not a bundle of grep flags.
  if grep -qE -- "$2" "$3"; then pass "$1"; else fail "$1 (got: $(tr '\n' ' ' <"$3" | cut -c1-220))"; fi
}

refute_log_matches() { # refute_log_matches <label> <extended-regex> <file>
  if grep -qE -- "$2" "$3"; then fail "$1 (matched '$2' in: $(tr '\n' ' ' <"$3" | cut -c1-220))"; else pass "$1"; fi
}

if [ ! -f "$SCRIPT" ]; then
  fail "shot script exists at scripts/shot.sh (not found: $SCRIPT)"
  printf '\n%d checks, %d failures\n' "$CHECKS" "$FAILURES" >&2
  exit 1
fi

# The system tools the sandbox below has to hand through: everything scripts/shot.sh
# (and the stub binary) legitimately needs, and nothing more. python3 is the suite's
# own: bash cannot create a unix socket, and the ydotoold probe is a `[ -S ]` test.
SANDBOX_TOOLS=(bash cat mktemp mkdir mv rm sleep awk id)
PREREQ_MISSING=0
for tool in "${SANDBOX_TOOLS[@]}" python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    fail "prerequisite: '$tool' is required to build the hermetic sandbox"
    PREREQ_MISSING=1
  fi
done
if [ "$PREREQ_MISSING" -ne 0 ]; then
  printf '\n%d checks, %d failures\n' "$CHECKS" "$FAILURES" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Never let a real ydotoold on the host leak in: every scenario pins this explicitly,
# so the driver's outcome is decided here and not by whether someone ran `ydotoold`.
YDOTOOL_SOCKET="$TMP/no-ydotoold-here.sock"

# mint_socket <path> — a REAL unix socket, so the script's `[ -S ]` probe passes.
# bind() leaves the filesystem entry behind after the process exits; that entry is
# all the probe looks at.
mint_socket() {
  rm -f "$1"
  python3 -c 'import socket, sys
s = socket.socket(socket.AF_UNIX)
s.bind(sys.argv[1])
s.close()' "$1"
}

# make_shims <mode>
#   full            — spectacle, magick and ydotool all present and working.
#   no-spectacle    — spectacle ABSENT.
#   no-ydotool      — ydotool ABSENT.
#   spectacle-fails — spectacle present, but the capture fails (KWin says no).
#   geom-drift      — the dark pass reports a different image geometry (i.e. the
#                     capture was of some other window).
#
# The shim dir becomes the ENTIRE PATH of the script under test. That is deliberate,
# and it is the fix for a real bug in the suite this one replaces: its `no-grim` mode
# merely OMITTED grim from a shim dir that was PREPENDED to the live PATH, so the
# script still found /usr/bin/grim — and the "missing tool fails loudly" scenario
# passed only because grim happens to be broken on THIS host (KWin cannot
# screencopy). On a wlroots box it would have gone red, or worse, captured the real
# screen. A tool a mode leaves out must be GENUINELY unreachable, and every `no-*`
# scenario below asserts that it is.
#
# `grim` and `slurp` are installed in EVERY mode as TRIPWIRES: they record the call
# and then fail loudly. grim is a dead backend here and slurp is not installed at all
# (R5.2), so a harness that reached for either would "work" in some other universe
# and break in this one. The suite catches the reach, not its consequences.
#
# Exports: SHIM, BIN_LOG, SPECTACLE_LOG, MAGICK_LOG, YDOTOOL_LOG, GRIM_LOG, SLURP_LOG.
make_shims() {
  local mode="$1"
  local tool
  local geom_light="1600x900"
  local geom_dark="1600x900"

  if [ "$mode" = "geom-drift" ]; then
    geom_dark="1280x720"
  fi

  SHIM="$TMP/$mode/bin"
  BIN_LOG="$TMP/$mode/bin.log"
  SPECTACLE_LOG="$TMP/$mode/spectacle.log"
  MAGICK_LOG="$TMP/$mode/magick.log"
  YDOTOOL_LOG="$TMP/$mode/ydotool.log"
  GRIM_LOG="$TMP/$mode/grim.log"
  SLURP_LOG="$TMP/$mode/slurp.log"

  rm -rf "${TMP:?}/$mode"
  mkdir -p "$SHIM"
  : >"$BIN_LOG"
  : >"$SPECTACLE_LOG"
  : >"$MAGICK_LOG"
  : >"$YDOTOOL_LOG"
  : >"$GRIM_LOG"
  : >"$SLURP_LOG"

  for tool in "${SANDBOX_TOOLS[@]}"; do
    ln -sf "$(command -v "$tool")" "$SHIM/$tool"
  done

  # `loginctl` is deliberately NOT in SANDBOX_TOOLS: with no loginctl on PATH the
  # lock probe cannot answer and fails OPEN, which is what every other scenario
  # wants (they are not testing the lock). Only this mode provides one, and it
  # reports the session as locked however the script chooses to ask.
  if [ "$mode" = "locked-session" ]; then
    cat >"$SHIM/loginctl" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *LockedHint*)    printf 'yes\n' ;;
  *list-sessions*) printf '7 1000 $(id -un) seat0 tty2\n' ;;
  *)               : ;;
esac
EOF
    chmod +x "$SHIM/loginctl"
  fi

  if [ "$mode" = "spectacle-fails" ]; then
    cat >"$SHIM/spectacle" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$SPECTACLE_LOG"
printf 'spectacle: KWin refused the screenshot request\n' >&2
exit 1
EOF
    chmod +x "$SHIM/spectacle"
  elif [ "$mode" != "no-spectacle" ]; then
    # `spectacle -a -b -n -o <file>`: parse -o properly rather than assuming it is
    # the last argument, so the assertions test the real flag and not an accident.
    # The stub writes REAL bytes: a zero-byte result can then only have come from the
    # script, never from here.
    cat >"$SHIM/spectacle" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$SPECTACLE_LOG"
out=""
prev=""
for arg in "\$@"; do
  case "\$prev" in
    -o|--output) out="\$arg" ;;
  esac
  prev="\$arg"
done
if [ -z "\$out" ]; then
  printf 'spectacle: background mode needs -o <file>\n' >&2
  exit 1
fi
printf 'fake-active-window-capture' >"\$out"
EOF
    chmod +x "$SHIM/spectacle"
  fi

  # `magick identify -format '%wx%h' <file>` — the VERIFIER. It refuses an empty or
  # missing file exactly as the real ImageMagick does, and reports the geometry the
  # mode asks for.
  cat >"$SHIM/magick" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$MAGICK_LOG"
src="\${*: -1}"
if [ ! -s "\$src" ]; then
  printf 'magick: unable to open image %s: empty or missing\n' "\$src" >&2
  exit 1
fi
case "\$src" in
  *-dark.png) printf '%s' '$geom_dark' ;;
  *)          printf '%s' '$geom_light' ;;
esac
EOF
  chmod +x "$SHIM/magick"

  if [ "$mode" != "no-ydotool" ]; then
    cat >"$SHIM/ydotool" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$YDOTOOL_LOG"
EOF
    chmod +x "$SHIM/ydotool"
  fi

  cat >"$SHIM/grim" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$GRIM_LOG"
printf 'grim: DEAD BACKEND — KWin has no wlr-screencopy. The harness must never call grim.\n' >&2
exit 1
EOF
  chmod +x "$SHIM/grim"

  cat >"$SHIM/slurp" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$SLURP_LOG"
printf 'slurp: this host has no slurp; the harness must never call it (R5.2).\n' >&2
exit 1
EOF
  chmod +x "$SHIM/slurp"
}

# make_bin <path> <exit-code> <log> [linger-secs]
# A stub "zeo": records its pid, its args, the config dir it was launched against and
# the settings.json it found there; optionally lingers (a window that stays up, so the
# no-stray-window contract can be tested); then exits with the requested code.
make_bin() {
  local path="$1" rc="$2" log="$3" linger="${4:-0}"
  cat >"$path" <<EOF
#!/usr/bin/env bash
set -uo pipefail
{
  printf 'launch pid=%s\n' "\$\$"
  printf 'launch args=%s\n' "\$*"
  printf 'launch XDG_CONFIG_HOME=%s\n' "\${XDG_CONFIG_HOME:-<unset>}"
  printf 'launch ZED_WINDOW_SIZE=%s\n' "\${ZED_WINDOW_SIZE:-<unset>}"
  if [ -f "\${XDG_CONFIG_HOME:-/nonexistent}/zeo/settings.json" ]; then
    printf 'launch settings=BEGIN\n'
    cat "\${XDG_CONFIG_HOME}/zeo/settings.json"
    printf 'launch settings=END\n'
  else
    printf 'launch settings=<none>\n'
  fi
} >>"$log"
if [ "$linger" != "0" ]; then
  trap 'exit 143' TERM INT
  sleep "$linger" &
  wait \$!
fi
exit $rc
EOF
  chmod +x "$path"
}

run_shot() { # run_shot <shim-dir> <args...> -> sets `rc` and writes $TMP/last.log
  local shim="$1"
  shift
  rc=0
  # PATH is REPLACED, not prepended: the sandbox is the only place the script can
  # find a tool, so a tool the mode leaves out is genuinely absent (see make_shims).
  PATH="$shim" YDOTOOL_SOCKET="$YDOTOOL_SOCKET" \
    bash "$SCRIPT" "$@" >"$TMP/last.log" 2>&1 || rc=$?
}

hidden_from() { # hidden_from <shim-dir> <tool> -> 0 when the tool is unreachable
  ! (
    PATH="$1"
    export PATH
    command -v "$2" >/dev/null 2>&1
  )
}

# --- Scenario 0: the evidence lands where git can actually see it ---------------
# `.epic` is the FIRST line of the workspace .gitignore. Shots written under it were
# committed into a void — the evidence commits were silent no-ops.
make_shims full
run_shot "$SHIM" --help
assert_zero "s0: --help exits 0" "$rc"
assert_log_matches "s0: the default out-dir is under docs/visual/ (versioned, not gitignored)" \
  'docs/visual/shots' "$TMP/last.log"
# No CODE line may name .epic — the comments are free to explain why we left it, and
# they should. What must not survive is a `.epic/...` path the script actually uses.
if grep -vE '^[[:space:]]*#' "$SCRIPT" | grep -qE -- '\.epic'; then
  fail "s0: no code line reaches into the gitignored .epic/ tree ($(grep -vE '^[[:space:]]*#' "$SCRIPT" | grep -E -- '\.epic' | head -1))"
else
  pass "s0: no code line reaches into the gitignored .epic/ tree (only the comment explaining why)"
fi

# --- Scenario 1: happy path — both appearances, window capture, throwaway config -
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
assert_eq "s1: spectacle captures exactly twice" \
  "2" "$(grep -c . "$SPECTACLE_LOG" || true)"

# The backend contract, asserted at the call site.
assert_log_matches "s1: captures the ACTIVE WINDOW (-a) — window-scoped, nothing to crop" \
  '(^| )(-a|--activewindow)( |$)' "$SPECTACLE_LOG"
assert_log_matches "s1: captures in the background (-b) — never raises the Spectacle UI" \
  '(^| )(-b|--background)( |$)' "$SPECTACLE_LOG"
assert_log_matches "s1: suppresses the desktop notification (-n) — it would land in the next shot" \
  '(^| )(-n|--nonotify)( |$)' "$SPECTACLE_LOG"
assert_log_matches "s1: writes the light pass to its own -o <file>" \
  '(-o|--output) [^ ]*command-palette-light\.png' "$SPECTACLE_LOG"
assert_log_matches "s1: writes the dark pass to its own -o <file>" \
  '(-o|--output) [^ ]*command-palette-dark\.png' "$SPECTACLE_LOG"

# Both appearances really are forced — not the same pass run twice.
assert_log_matches "s1: the light pass pins its appearance in the throwaway settings.json" \
  '"mode":[[:space:]]*"light"' "$BIN_LOG"
assert_log_matches "s1: the dark pass pins its appearance in the throwaway settings.json" \
  '"mode":[[:space:]]*"dark"' "$BIN_LOG"

# The theme NAMES are pinned alongside the mode, not just the mode. ThemeSelection is
# #[serde(untagged)] and its Dynamic variant requires BOTH `light` and `dark`, so a
# settings file carrying only {"mode": …} fails to deserialise — which rejects the
# WHOLE file, and the appearance is then SILENTLY not pinned at all.
assert_log_matches "s1: pins the theme NAMES too (stock One Light / One Dark by default)" \
  '"light":[[:space:]]*"One Light"' "$BIN_LOG"

# R5.1: the fixture cannot drift between passes — the window bounds are pinned.
assert_eq "s1: pins the window size for every pass (a fixed fixture, R5.1)" \
  "2" "$(grep -c '^launch ZED_WINDOW_SIZE=1600,900$' "$BIN_LOG" || true)"

# The user's real profile must never be touched (a capture that inherits the user's
# settings is not a fixture — and it can mutate their config).
if grep -q "^launch XDG_CONFIG_HOME=${HOME}/.config$" "$BIN_LOG"; then
  fail "s1: launches against a throwaway config dir, never \$HOME/.config"
elif grep -q '^launch XDG_CONFIG_HOME=<unset>$' "$BIN_LOG"; then
  fail "s1: launches against a throwaway config dir (XDG_CONFIG_HOME was not set at all)"
else
  pass "s1: launches against a throwaway config dir, never \$HOME/.config"
fi

# The two tripwires.
assert_eq "s1: never invokes slurp (absent here — an interactive region, R5.2)" \
  "" "$(cat "$SLURP_LOG")"
assert_eq "s1: never invokes grim (dead backend — KWin has no wlr-screencopy)" \
  "" "$(cat "$GRIM_LOG")"

# The crop is GONE: `spectacle -a` is window-scoped already, and a fixed full-screen
# crop box was the fragile half — it drifts with the screen resolution and the panel
# layout. magick survives as a VERIFIER of what was captured, not as a cropper.
refute_log_matches "s1: performs no fixed-coordinate crop (a window capture needs none)" \
  '-crop' "$MAGICK_LOG"
assert_eq "s1: verifies both captures decode as real images (magick identify)" \
  "2" "$(grep -c 'identify' "$MAGICK_LOG" || true)"

# --- Scenario 2: `spectacle` missing -> loud failure, never a zero-byte PNG ------
make_shims no-spectacle
BIN="$TMP/zeo-ok2"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s2"

# THE META-ASSERTION, and the reason this scenario is worth anything. The suite this
# replaces got it wrong: it shadowed the tool instead of removing it, and passed for
# a host-specific reason. Absence must be REAL.
if hidden_from "$SHIM" spectacle; then
  pass "s2: the shim genuinely hides spectacle (unreachable on PATH, not merely shadowed)"
else
  fail "s2: the shim genuinely hides spectacle — it is still reachable, so this scenario proves nothing"
fi

run_shot "$SHIM" --label before --surface popover \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s2: exits non-zero when spectacle is unavailable" "$rc"
assert_log_matches "s2: the failure message names spectacle" \
  'spectacle' "$TMP/last.log"
assert_no_png "s2: emits no PNG at all — not even a zero-byte one" "$OUT"
assert_file_empty "s2: never launches the binary — a missing tool leaves no window" "$BIN_LOG"

# --- Scenario 3: launch failure -> non-zero, no partial output -------------------
make_shims full
BIN="$TMP/zeo-broken"
make_bin "$BIN" 1 "$BIN_LOG"
OUT="$TMP/shots-s3"

run_shot "$SHIM" --label after --surface modal \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s3: exits non-zero when the binary fails to launch" "$rc"
assert_log_matches "s3: the failure message names the step that failed" \
  'launch|start' "$TMP/last.log"
assert_no_png "s3: leaves no partial output behind" "$OUT"
assert_file_empty "s3: never reaches the capture step" "$SPECTACLE_LOG"

# --- Scenario 4: argument validation --------------------------------------------
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

# --crop retired with the crop step. A caller written against the old interface has to
# be TOLD, not silently obeyed with the flag dropped on the floor.
run_shot "$SHIM" --label before --surface modal --bin "$BIN" --out-dir "$OUT" --settle 0 \
  --crop 1600x900+160+90
assert_nonzero "s4: rejects the retired --crop flag instead of ignoring it" "$rc"

assert_no_png "s4: writes nothing when the arguments are rejected" "$OUT"

# --- Scenario 5: the driver (--keys) --------------------------------------------
# A driver that cannot fire would capture the undriven editor UNDER THE DRIVEN
# SURFACE'S NAME — a silently corrupt before/after pair, which is worse than no pair.
# So an unusable input backend is fatal, and fatal BEFORE the binary is launched.

# 5a — ydotool is not installed at all.
make_shims no-ydotool
BIN="$TMP/zeo-ok5a"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s5a"

if hidden_from "$SHIM" ydotool; then
  pass "s5a: the shim genuinely hides ydotool (unreachable on PATH, not merely shadowed)"
else
  fail "s5a: the shim genuinely hides ydotool — it is still reachable, so this scenario proves nothing"
fi

run_shot "$SHIM" --label before --surface command-palette --keys ctrl+shift+p \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s5a: exits non-zero when --keys is asked for and ydotool is absent" "$rc"
assert_log_matches "s5a: the failure names the missing capability" \
  'ydotool' "$TMP/last.log"
assert_log_matches "s5a: the failure names the surface that would have been corrupted" \
  'command-palette' "$TMP/last.log"
assert_file_empty "s5a: fails BEFORE launching — no window is ever put on screen" "$BIN_LOG"
assert_no_png "s5a: writes no PNG" "$OUT"

# 5b — ydotool is installed, but ydotoold is not running. The likelier real failure:
# the binary is packaged, the daemon needs sudo.
make_shims full
BIN="$TMP/zeo-ok5b"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s5b"
YDOTOOL_SOCKET="$TMP/ydotoold-is-not-running.sock"

run_shot "$SHIM" --label before --surface file-picker --keys ctrl+p \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s5b: exits non-zero when ydotoold's socket is not there" "$rc"
assert_log_matches "s5b: the failure names the daemon that is not running" \
  'ydotoold' "$TMP/last.log"
assert_file_empty "s5b: fails BEFORE launching — no window is ever put on screen" "$BIN_LOG"
assert_no_png "s5b: writes no PNG" "$OUT"

# 5c — the driver works: the chord fires, and the window is still captured.
make_shims full
BIN="$TMP/zeo-ok5c"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s5c"
YDOTOOL_SOCKET="$TMP/ydotoold.sock"
mint_socket "$YDOTOOL_SOCKET"
if [ -S "$YDOTOOL_SOCKET" ]; then
  pass "s5c: the suite mints a real ydotoold socket (the probe is a [ -S ] test)"
else
  fail "s5c: the suite mints a real ydotoold socket (no socket at $YDOTOOL_SOCKET)"
fi

run_shot "$SHIM" --label after --surface command-palette --keys ctrl+shift+p \
  --bin "$BIN" --out-dir "$OUT" --settle 0 \
  --theme-light 'Zeo Light' --theme-dark 'Zeo Dark'
assert_zero "s5c: exits 0 when the driver can fire" "$rc"
assert_file_nonempty "s5c: still emits the light PNG" "$OUT/after/command-palette-light.png"
assert_file_nonempty "s5c: still emits the dark PNG" "$OUT/after/command-palette-dark.png"
# ctrl(29) + shift(42) + p(25): pressed in order, released in reverse. Once per pass.
assert_eq "s5c: sends the chord as evdev press/release events, once per pass" \
  "2" "$(grep -c '^key 29:1 42:1 25:1 25:0 42:0 29:0$' "$YDOTOOL_LOG" || true)"
assert_log_matches "s5c: --theme-light pins the requested name (7.1 must capture under 'Zeo Light')" \
  '"light":[[:space:]]*"Zeo Light"' "$BIN_LOG"
assert_log_matches "s5c: --theme-dark pins the requested name (7.1 must capture under 'Zeo Dark')" \
  '"dark":[[:space:]]*"Zeo Dark"' "$BIN_LOG"

YDOTOOL_SOCKET="$TMP/no-ydotoold-here.sock"

# --- Scenario 6: a failed capture leaves no partial output AND NO STRAY WINDOW ---
# The app is still up when the capture fails. The script must take it down: a leftover
# window would corrupt the next pass, and with `spectacle -a` there would be two Zeo
# windows on screen and the capture would take whichever happened to be active.
make_shims spectacle-fails
BIN="$TMP/zeo-lingers"
make_bin "$BIN" 0 "$BIN_LOG" 10
OUT="$TMP/shots-s6"

run_shot "$SHIM" --label before --surface editor \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s6: exits non-zero when the capture itself fails" "$rc"
assert_log_matches "s6: the failure message names the capture step" \
  'spectacle' "$TMP/last.log"
assert_no_png "s6: leaves no partial output behind" "$OUT"

app_pid="$(grep '^launch pid=' "$BIN_LOG" | head -1 | cut -d= -f2 || true)"
if [ -z "$app_pid" ]; then
  fail "s6: the stub app recorded its pid (test setup is broken)"
elif kill -0 "$app_pid" 2>/dev/null; then
  fail "s6: leaves NO STRAY WINDOW — the app process ($app_pid) is still running"
  kill -9 "$app_pid" 2>/dev/null || true
else
  pass "s6: leaves NO STRAY WINDOW — the app process was taken down on the way out"
fi

# --- Scenario 7: the pair must be diffable (R5.1) --------------------------------
# `spectacle -a` captures whatever window is ACTIVE. If focus is stolen mid-run, the
# capture is of the WRONG WINDOW — and it looks perfectly plausible. The mechanical
# tell is the geometry: both passes are the same pinned window, so they cannot differ.
make_shims geom-drift
BIN="$TMP/zeo-ok7"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s7"

run_shot "$SHIM" --label before --surface editor \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s7: exits non-zero when the two passes captured different geometries" "$rc"
assert_log_matches "s7: the failure says the pair would not be diffable" \
  'geometr|diffable|drift' "$TMP/last.log"
assert_no_png "s7: publishes nothing — a non-diffable pair is worse than no pair" "$OUT"

# --- Scenario 8: the two warnings that keep a plausible capture from lying --------
make_shims full
BIN="$TMP/zeo-ok8"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s8"

# An `after` pass left on the stock theme names would produce a before/after pair that
# differs in NOTHING. It still runs — the operator may have a reason — but it says so.
run_shot "$SHIM" --label after --surface editor \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_zero "s8: --label after with the stock themes still captures" "$rc"
assert_log_matches "s8: ...but warns that it will NOT show Zeo's own theme" \
  'WARN.*after.*stock themes' "$TMP/last.log"

# A driven surface with no --keys shows the EDITOR, under the driven surface's name.
make_shims full
BIN="$TMP/zeo-ok8b"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s8b"

run_shot "$SHIM" --label before --surface command-palette \
  --bin "$BIN" --out-dir "$OUT" --settle 0
assert_zero "s8: a driven surface with no --keys still captures" "$rc"
assert_log_matches "s8: ...but warns that it is being captured AT REST (the PNG shows the editor)" \
  'WARN.*AT REST' "$TMP/last.log"

# --- Scenario 9: a LOCKED session is refused, before anything is launched ---------
#
# The worst capture this script can produce is not a missing one — it is a blank one
# that looks right. With the session locked, KWin does not paint the contents of the
# windows the lock screen occludes, so `spectacle -a` returns a correctly-sized,
# non-zero, perfectly-decodable PNG of an EMPTY pane. Every guard downstream waves it
# through: the file is non-empty (s2's check), it decodes (s1's check), and the
# geometry pair-check (s7) passes because BOTH passes are equally blank.
#
# This is not hypothetical. It happened during the real capture run for story 002 and
# was caught only by accident, by taking a full-screen shot outside the harness. Two
# innocent causes were blamed first. The only place the check can work is BEFORE the
# launch, which is where it now lives — and this scenario is what keeps it there.
make_shims locked-session
BIN="$TMP/locked-session/zeo"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s9"

run_shot "$SHIM" --label before --surface editor --bin "$BIN" --out-dir "$OUT" --settle 0
assert_nonzero "s9: a locked session is fatal — it does not capture a blank window" "$rc"
assert_log_matches "s9: ...and says so, naming the lock rather than some downstream symptom" \
  'LOCKED' "$TMP/last.log"
assert_no_png "s9: no PNG is written — not even a plausible, correctly-sized, empty one" "$OUT"
assert_eq "s9: the binary is never launched (no window is put on a locked screen)" \
  "0" "$(grep -c '^launch args=' "$BIN_LOG" || true)"
assert_eq "s9: spectacle is never invoked" \
  "0" "$(grep -c . "$SPECTACLE_LOG" || true)"

# The mirror image, and the assertion that keeps the guard from being vacuous: with no
# lock reported, the SAME invocation must succeed. A guard that refuses everything
# would pass every check above and quietly kill the harness.
make_shims full
BIN="$TMP/full/zeo"
make_bin "$BIN" 0 "$BIN_LOG"
OUT="$TMP/shots-s9b"

run_shot "$SHIM" --label before --surface editor --bin "$BIN" --out-dir "$OUT" --settle 0
assert_zero "s9: an UNLOCKED session still captures (the guard is not a blanket refusal)" "$rc"
assert_file_nonempty "s9: ...and emits its PNGs as normal" "$OUT/before/editor-dark.png"

# --- Summary ---------------------------------------------------------------------
printf '\n%d checks, %d failures\n' "$CHECKS" "$FAILURES"
if [ "$FAILURES" -ne 0 ]; then
  exit 1
fi
