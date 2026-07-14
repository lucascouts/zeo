#!/usr/bin/env bash
#
# Capture one Zeo surface, in both appearances, from a fixed fixture.
#
#   shot.sh --label <before|after> --surface <name>
#           [--bin <path>] [--out-dir <path>] [--settle <secs>]
#           [--keys <chord>]... [--theme-light <name>] [--theme-dark <name>]
#
# Every invocation runs TWO passes — one per appearance. Each pass launches the
# binary against a THROWAWAY profile (an XDG_CONFIG_HOME + XDG_DATA_HOME under a
# temp dir; never the user's ~/.config), whose settings.json pins the appearance
# AND the theme names for that pass, opens a fixed fixture file at a fixed window
# size, optionally drives the surface open with synthetic keystrokes, and captures
# THE ACTIVE WINDOW with `spectacle`.
#
# CAPTURE BACKEND: `spectacle`, NOT `grim`. KWin does not implement the
# `wlr-screencopy` protocol that grim requires — `grim -g '0,0 1x1' out.png` prints
# "compositor doesn't support the screen capture protocol", exits 1 and writes no
# file. Every capture on this host must go through KWin's own screenshot service,
# which is what spectacle speaks. design.md §9 already named it as the fallback.
#
# The swap DELETES the fixed-coordinate crop, and that is a strengthening, not a
# concession. `spectacle -a` captures the active WINDOW, so the capture is already
# window-scoped: it cannot drift with the screen resolution or the panel layout,
# which a fixed full-screen crop box does. It is also why `slurp`'s absence (R5.2)
# stopped mattering — there was never an interactive region to select, and now
# there is not even a region to crop.
#
# `magick` survives as a VERIFIER, not a cropper: it proves each capture decodes as
# a real image, and that both passes captured the SAME geometry (R5.1). That pair
# check is the one mechanical defence against the failure mode `-a` introduces —
# spectacle capturing whatever window happened to be active instead of Zeo.
#
# Output is transactional: both captures are staged in the temp dir and published
# to <out-dir>/<label>/ only once BOTH passes have succeeded. Any failure exits
# non-zero naming the step that failed, leaves no window behind, and emits no PNG
# at all — never a zero-byte file, and never a plausible-looking capture of the
# wrong state.

set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
if [ "$SCRIPT_DIR" = "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="."
fi
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly REPO_ROOT

readonly DEFAULT_THEME_LIGHT="One Light"
readonly DEFAULT_THEME_DARK="One Dark"

# The shots live under docs/, NOT under .epic/. `.epic` is the FIRST line of the
# workspace .gitignore, so anything written there can never be committed: the
# evidence commits that pointed at it were silent no-ops. Evidence has to be
# versioned to be evidence.
DEFAULT_OUT_DIR="$REPO_ROOT/docs/visual/shots"
readonly DEFAULT_OUT_DIR
# docs/BUILD.md: the release build lands in the FORK's target dir, not a workspace one.
DEFAULT_BIN="$REPO_ROOT/fork/target/release/zeo"
readonly DEFAULT_BIN

LABEL=""
SURFACE=""
BIN="$DEFAULT_BIN"
OUT_DIR="$DEFAULT_OUT_DIR"
SETTLE="3"
THEME_LIGHT="$DEFAULT_THEME_LIGHT"
THEME_DARK="$DEFAULT_THEME_DARK"
KEYS=()

# GOTCHA: the throwaway config dir means the fixture is an UNTRUSTED worktree, so Zed
# raises its "Unrecognized Project / Restricted Mode" modal over the editor. That modal
# does two things, and the second is the dangerous one: it covers the very surface the
# capture exists to show, and it HOLDS FOCUS -- so every --keys chord would be delivered
# to the modal instead of the editor, and the driven surfaces would silently capture the
# wrong thing. `session.trust_all_worktrees` dismisses it declaratively; sending `enter`
# would work too, but only if the keystroke lands, which is exactly the kind of thing that
# fails once and is never noticed. The key predates story 002 (it is in the baseline
# commit), so the banked pre-change binary parses it too -- had it not, the whole settings
# file would have been rejected and the THEME would have gone silently unpinned.

# The fixture. Pinned here — not chosen at run time — so that every before/after
# pair is the same window, showing the same file, from the same clean profile.
#
# The fork honours a window-bounds override only when position AND size are both
# set (workspace.rs: ZED_WINDOW_POSITION.zip(ZED_WINDOW_SIZE)); both are "X,Y".
readonly WINDOW_SIZE="1600,900"
readonly WINDOW_POSITION="160,90"
# A deterministic directory name: it is the fixture's parent, so it is what the
# title bar shows. A raw `mktemp -d` basename would differ between runs and put
# random text inside the captured window.
readonly FIXTURE_DIR_NAME="zeo-fixture"
readonly FIXTURE_FILE_NAME="main.rs"
# $XDG_CONFIG_HOME/<subdir>/settings.json — paths.rs: APP_NAME_LOWERCASE.
readonly APP_CONFIG_SUBDIR="zeo"

# A launch that dies instantly is a failed launch even when --settle is 0, so
# always give the process at least this long to fail before trusting it.
readonly LAUNCH_GRACE="0.5"
# Time for the UI to react to each driver chord before the next one (or the capture).
readonly KEY_DELAY="0.4"

WORK=""
APP_PID=""
KEY_EVENTS=()
CAPTURE_GEOMETRY=""
PASS_GEOMETRY=()

usage() {
    cat <<EOF
Usage: shot.sh --label <before|after> --surface <name> [options]

  --label        before | after                    (required)
  --surface      surface name, used in the filename (required)
  --bin          binary to capture                 (default: $DEFAULT_BIN)
  --out-dir      root of the shot tree             (default: $DEFAULT_OUT_DIR)
  --settle       seconds to wait for the window    (default: 3)
  --keys         driver chord, repeatable          (e.g. --keys ctrl+shift+p)
  --theme-light  theme pinned in the light pass    (default: $DEFAULT_THEME_LIGHT)
  --theme-dark   theme pinned in the dark pass     (default: $DEFAULT_THEME_DARK)

Emits <out-dir>/<label>/<surface>-light.png and <surface>-dark.png.

Capture: \`spectacle -a -b -n -o <file>\` — the ACTIVE WINDOW, in the background,
without a notification. There is no crop: the capture is window-scoped already.
\`grim\` is never used (KWin has no wlr-screencopy — grim cannot capture here), and
\`slurp\` is never used (an interactive region would make the pairs non-comparable).

  GOTCHA: because the capture is of the ACTIVE window, the Zeo window must still be
  the active one when it fires. Do not click away, and do not let a notification or
  a prompt steal focus, during a run. A capture of the wrong window is caught only
  if it is a different SIZE (see below) — otherwise it looks plausible.

Driving a surface (--keys):
  \`editor\` is the editor at rest: it needs no synthetic input and works with no
  daemon and no sudo. Every other surface has to be opened with keystrokes, which
  are sent with ydotool and therefore need \`ydotoold\` running:

      sudo ydotoold &            # then, e.g.
      shot.sh --label before --surface command-palette --keys ctrl+shift+p

  Suggested chords: command-palette ctrl+shift+p | file-picker ctrl+p |
  project-search ctrl+shift+f | outline ctrl+shift+o | theme-selector ctrl+k ctrl+t
  (a sequence is several --keys: --keys ctrl+k --keys ctrl+t).

  Chord syntax: \`+\`-joined names — ctrl, shift, alt, super, a-z, 0-9, escape,
  enter, tab, space, backspace, delete, up, down, left, right, home, end, comma,
  period, slash, semicolon, minus, equal, f1-f12.

  Without --keys, a non-\`editor\` surface is captured AT REST — the PNG shows the
  editor, not the surface. The script says so loudly; it cannot know better.

Themes: the appearance (light/dark) is what the two passes vary, but the theme
NAMES have to be pinned too (the fork's ThemeSelection requires both). They default
to the stock ones, which is what the \`before\` pass wants; give the \`after\` pass
Zeo's own theme names with --theme-light/--theme-dark.

Exit status: 0 when both PNGs are written; non-zero (naming the failed step, with
no PNG written at all) otherwise.
EOF
}

die() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

warn() {
    printf 'WARN: %s\n' "$1" >&2
}

# No stray window, whatever happens (a leftover window would also corrupt the next
# pass: two Zeo windows, and `spectacle -a` would capture whichever is active).
stop_app() {
    local i

    [ -n "$APP_PID" ] || return 0

    if kill -0 "$APP_PID" 2>/dev/null; then
        kill "$APP_PID" 2>/dev/null || true
        for ((i = 0; i < 20; i++)); do
            kill -0 "$APP_PID" 2>/dev/null || break
            sleep 0.1
        done
        if kill -0 "$APP_PID" 2>/dev/null; then
            kill -9 "$APP_PID" 2>/dev/null || true
        fi
    fi

    wait "$APP_PID" 2>/dev/null || true
    APP_PID=""
}

cleanup() {
    stop_app
    if [ -n "$WORK" ] && [ -d "$WORK" ]; then
        rm -rf "$WORK"
    fi
}
trap cleanup EXIT

while [ "$#" -gt 0 ]; do
    case "$1" in
        --label)       LABEL="${2:?--label needs before|after}";                shift 2 ;;
        --surface)     SURFACE="${2:?--surface needs a name}";                  shift 2 ;;
        --bin)         BIN="${2:?--bin needs a path}";                          shift 2 ;;
        --out-dir)     OUT_DIR="${2:?--out-dir needs a path}";                  shift 2 ;;
        --settle)      SETTLE="${2:?--settle needs seconds}";                   shift 2 ;;
        --keys)        KEYS+=("${2:?--keys needs a chord, e.g. ctrl+shift+p}"); shift 2 ;;
        --theme-light) THEME_LIGHT="${2:?--theme-light needs a theme name}";    shift 2 ;;
        --theme-dark)  THEME_DARK="${2:?--theme-dark needs a theme name}";      shift 2 ;;
        -h|--help)     usage; exit 0 ;;
        *) printf 'unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

# --- Arguments: reject before anything is created, so a bad call writes nothing.

case "$LABEL" in
    before|after) ;;
    "") die "--label is required: before or after" ;;
    *)  die "--label must be 'before' or 'after' (got '$LABEL')" ;;
esac

if [ -z "$SURFACE" ]; then
    die "--surface is required (e.g. editor, command-palette)"
fi
if ! [[ "$SURFACE" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    die "--surface must be a plain name (letters, digits, . _ -), got '$SURFACE'"
fi
if ! [[ "$SETTLE" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    die "--settle must be a non-negative number of seconds (got '$SETTLE')"
fi
if [[ "$THEME_LIGHT$THEME_DARK" == *[\"\\]* ]]; then
    die "theme names must not contain quotes or backslashes"
fi

# --- Surfaces: which need a driver, and what to drive them with.

# Prints the chord(s) that open a surface, or nothing when there is no known one.
suggested_keys() {
    case "$1" in
        command-palette) printf '%s' 'ctrl+shift+p' ;;
        file-picker)     printf '%s' 'ctrl+p' ;;
        project-search)  printf '%s' 'ctrl+shift+f' ;;
        outline)         printf '%s' 'ctrl+shift+o' ;;
        theme-selector)  printf '%s' 'ctrl+k ctrl+t' ;;
        *)               printf '' ;;
    esac
}

# Surfaces that ARE the fixture at rest: no synthetic input, no daemon, no sudo.
is_at_rest_surface() {
    case "$1" in
        editor|editor-*) return 0 ;;
        *) return 1 ;;
    esac
}

# The theme pinned for one appearance.
theme_for() {
    case "$1" in
        dark) printf '%s' "$THEME_DARK" ;;
        *)    printf '%s' "$THEME_LIGHT" ;;
    esac
}

# --- Tools: fail before launching anything, so a missing tool leaves no window.

# `spectacle` captures; `magick` verifies what it captured. `grim` is NOT here on
# purpose — it is a dead backend on KWin, and reaching for it is the bug this
# script was rewritten to remove.
for tool in spectacle magick; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        die "$tool is not installed: cannot capture. No PNG written."
    fi
done

# A capture taken while the session is LOCKED comes back the right size, with the
# right name, and exit 0 — and BLANK inside. KWin does not paint the contents of
# windows the lock screen occludes, so `spectacle -a` hands back a perfectly
# well-formed PNG of an empty pane.
#
# This is the worst failure this script can have, and it is worse than a crash: not a
# MISSING capture but a WRONG one that looks right. Every downstream guard waves it
# through — the file is non-zero, it decodes, and the geometry pair-check passes
# because BOTH passes are equally blank. Nothing in the artefact says "this is a
# picture of nothing". So the check cannot live after the capture; it has to happen
# here, before a window is ever launched.
#
# Found the hard way, and only by accident: a run against the banked baseline binary
# produced flawless, empty PNGs, and it took a FULL-SCREEN capture — outside the
# harness — to see the lock screen and understand why. Two wrong causes were blamed
# first (the trust modal, then --settle). This guard is the cheap version of that
# afternoon.
session_is_locked() {
    local session_id locked

    command -v loginctl >/dev/null 2>&1 || return 1

    session_id="${XDG_SESSION_ID:-}"
    if [ -z "$session_id" ]; then
        session_id="$(loginctl --no-legend list-sessions 2>/dev/null |
            awk -v user="$(id -un)" '$3 == user { print $1; exit }')"
    fi
    [ -n "$session_id" ] || return 1

    locked="$(loginctl show-session "$session_id" --property=LockedHint --value 2>/dev/null || true)"
    [ "$locked" = "yes" ]
}

if session_is_locked; then
    die "the desktop session is LOCKED. A capture taken now would be correctly sized, non-empty and BLANK — KWin does not paint occluded windows, and no check downstream can tell the difference. Unlock the session, keep it unlocked, and re-run. No PNG written."
fi

if [ "${#KEYS[@]}" -gt 0 ]; then
    # Probe ydotool for real; never assume. A driver that cannot fire would capture
    # the undriven editor under the driven surface's name, silently corrupting the
    # before/after pair — so this is fatal, not a warning, and it is fatal BEFORE
    # the binary is launched, so no window is ever put on screen.
    ydotool_socket="${YDOTOOL_SOCKET:-/run/user/$(id -u)/.ydotool_socket}"
    if ! command -v ydotool >/dev/null 2>&1; then
        die "surface '$SURFACE' needs synthetic input (--keys ${KEYS[*]}), but ydotool is not installed. No PNG written."
    fi
    if [ ! -S "$ydotool_socket" ]; then
        die "surface '$SURFACE' needs synthetic input (--keys ${KEYS[*]}), but ydotoold is not reachable (no socket at $ydotool_socket) — start it with 'sudo ydotoold'. No PNG written."
    fi
elif ! is_at_rest_surface "$SURFACE"; then
    hint="$(suggested_keys "$SURFACE")"
    if [ -n "$hint" ]; then
        hint="--keys $hint"
    else
        hint="--keys <chord> (no chord is known for this surface)"
    fi
    warn "surface '$SURFACE' is being captured AT REST: with no --keys, the PNG shows the editor, not '$SURFACE'. Drive it with $hint (needs 'sudo ydotoold')."
fi

if [ "$LABEL" = "after" ] &&
    [ "$THEME_LIGHT" = "$DEFAULT_THEME_LIGHT" ] &&
    [ "$THEME_DARK" = "$DEFAULT_THEME_DARK" ]; then
    warn "--label after is pinning the stock themes ($THEME_LIGHT / $THEME_DARK): this capture will NOT show Zeo's own theme. Pass --theme-light/--theme-dark."
fi

if [ ! -x "$BIN" ]; then
    die "launch: no executable binary at '$BIN' (--bin). No PNG written."
fi

# --- Driver: a chord becomes evdev press/release events for `ydotool key`.

# Prints the evdev keycode for a key name; returns 1 when the name is unknown.
keycode_for() {
    case "$1" in
        ctrl|control)   printf '29' ;;
        shift)          printf '42' ;;
        alt)            printf '56' ;;
        super|meta|win) printf '125' ;;
        a) printf '30'  ;; b) printf '48'  ;; c) printf '46'  ;; d) printf '32' ;;
        e) printf '18'  ;; f) printf '33'  ;; g) printf '34'  ;; h) printf '35' ;;
        i) printf '23'  ;; j) printf '36'  ;; k) printf '37'  ;; l) printf '38' ;;
        m) printf '50'  ;; n) printf '49'  ;; o) printf '24'  ;; p) printf '25' ;;
        q) printf '16'  ;; r) printf '19'  ;; s) printf '31'  ;; t) printf '20' ;;
        u) printf '22'  ;; v) printf '47'  ;; w) printf '17'  ;; x) printf '45' ;;
        y) printf '21'  ;; z) printf '44'  ;;
        1) printf '2'   ;; 2) printf '3'   ;; 3) printf '4'   ;; 4) printf '5'  ;;
        5) printf '6'   ;; 6) printf '7'   ;; 7) printf '8'   ;; 8) printf '9'  ;;
        9) printf '10'  ;; 0) printf '11'  ;;
        escape|esc)     printf '1' ;;
        enter|return)   printf '28' ;;
        tab)            printf '15' ;;
        space)          printf '57' ;;
        backspace)      printf '14' ;;
        delete)         printf '111' ;;
        up)             printf '103' ;;
        down)           printf '108' ;;
        left)           printf '105' ;;
        right)          printf '106' ;;
        home)           printf '102' ;;
        end)            printf '107' ;;
        comma)          printf '51' ;;
        period)         printf '52' ;;
        slash)          printf '53' ;;
        semicolon)      printf '39' ;;
        minus)          printf '12' ;;
        equal)          printf '13' ;;
        f1)  printf '59' ;; f2)  printf '60' ;; f3)  printf '61' ;; f4)  printf '62' ;;
        f5)  printf '63' ;; f6)  printf '64' ;; f7)  printf '65' ;; f8)  printf '66' ;;
        f9)  printf '67' ;; f10) printf '68' ;; f11) printf '87' ;; f12) printf '88' ;;
        *) return 1 ;;
    esac
}

# Fills KEY_EVENTS with the press-then-release-in-reverse events for one chord.
chord_events() {
    local chord="$1"
    local -a parts=()
    local -a codes=()
    local part code i

    IFS='+' read -r -a parts <<<"$chord"
    for part in "${parts[@]}"; do
        part="${part,,}"
        if [ -z "$part" ]; then
            die "driver: malformed chord '$chord' in --keys"
        fi
        if ! code="$(keycode_for "$part")"; then
            die "driver: unknown key '$part' in chord '$chord' (see --help for the key names)"
        fi
        codes+=("$code")
    done

    KEY_EVENTS=()
    for code in "${codes[@]}"; do
        KEY_EVENTS+=("$code:1")
    done
    for ((i = ${#codes[@]} - 1; i >= 0; i--)); do
        KEY_EVENTS+=("${codes[i]}:0")
    done
}

drive_surface() {
    local chord

    [ "${#KEYS[@]}" -gt 0 ] || return 0

    for chord in "${KEYS[@]}"; do
        chord_events "$chord"
        printf 'driving %s: %s (%s)\n' "$SURFACE" "$chord" "${KEY_EVENTS[*]}"
        if ! ydotool key "${KEY_EVENTS[@]}"; then
            die "driver: ydotool could not send '$chord' for surface '$SURFACE'. No PNG written."
        fi
        sleep "$KEY_DELAY"
    done
}

# --- The fixture, the profile, and one pass.

write_fixture() {
    cat <<'EOF'
// The Zeo screenshot fixture. Pinned: every before/after pair is this file, in
// this window, so that the two captures compare like with like (R5.1).
use std::collections::HashMap;

/// A crystal facet: an edge of the shard, and the light it throws.
#[derive(Debug, Clone, PartialEq)]
pub struct Facet {
    pub name: String,
    pub radius: f32,
    pub visible: bool,
}

impl Facet {
    pub fn new(name: &str, radius: f32) -> Self {
        Self {
            name: name.to_string(),
            radius,
            visible: true,
        }
    }

    pub fn refract(&self, angle: f32) -> Option<f32> {
        if !self.visible || self.radius <= 0.0 {
            return None;
        }
        Some((angle * self.radius).clamp(0.0, 360.0))
    }
}

fn main() {
    let mut shard: HashMap<&str, Facet> = HashMap::new();
    shard.insert("edge", Facet::new("edge", 12.5));

    for (key, facet) in &shard {
        match facet.refract(45.0) {
            Some(angle) => println!("{key}: {angle:.2}°"),
            None => eprintln!("{key}: opaque"),
        }
    }
}
EOF
}

# The throwaway profile for one pass: it pins the appearance, and it exists so that
# the user's real ~/.config is never read and never touched.
#
# The theme NAMES are pinned alongside the mode, not merely the mode. ThemeSelection
# (settings_content/src/theme.rs:274-287) is #[serde(untagged)] and its Dynamic
# variant requires BOTH `light` and `dark`; only `mode` carries #[serde(default)].
# A settings file containing just {"mode":"light"} fails to deserialise, which
# rejects the WHOLE file — so the appearance would be SILENTLY not pinned, and
# R5.1's "same fixture" guarantee would be void.
write_settings() {
    local mode="$1"

    cat <<EOF
{
  "theme": {
    "mode": "$mode",
    "light": "$THEME_LIGHT",
    "dark": "$THEME_DARK"
  },
  "restore_on_startup": "none",
  "auto_update": false,
  "telemetry": {
    "diagnostics": false,
    "metrics": false
  },
  "session": {
    "trust_all_worktrees": true
  }
}
EOF
}

# How many 100ms polls one pass waits: --settle, but never less than the grace that
# makes an instantly-dying launch detectable rather than a race.
settle_steps() {
    awk -v settle="$SETTLE" -v grace="$LAUNCH_GRACE" 'BEGIN {
        seconds = (settle > grace ? settle : grace)
        steps = int(seconds * 10 + 0.5)
        print (steps < 1 ? 1 : steps)
    }'
}

# Waits for the window to settle, and turns a process that died on us into a named
# failure. Returns with APP_PID cleared if the process is already gone.
await_window() {
    local mode="$1"
    local steps i status

    steps="$(settle_steps)"

    for ((i = 0; i < steps; i++)); do
        if ! kill -0 "$APP_PID" 2>/dev/null; then
            status=0
            wait "$APP_PID" || status=$?
            APP_PID=""
            if [ "$status" -ne 0 ]; then
                die "launch: $BIN exited with status $status during the $mode pass — no window to capture. No PNG written."
            fi
            warn "launch: $BIN exited cleanly during the $mode pass; capturing the output as it stands."
            return 0
        fi
        sleep 0.1
    done
}

# The capture. `spectacle -a` takes the ACTIVE WINDOW through KWin's own screenshot
# service — window-scoped, so there is nothing to crop and nothing to select
# interactively (R5.2: `slurp` is absent and is never invoked; `grim` cannot capture
# on KWin at all and is never invoked either).
capture_window() {
    local out="$1" mode="$2"
    #  -a = --activewindow   the window, not the screen
    #  -b = --background     capture and exit; never show the Spectacle UI
    #  -n = --nonotify       no desktop notification (it would land in the next shot)
    #  -o = --output <file>  write here
    local -a cmd=(spectacle -a -b -n -o "$out")

    rm -f "$out"

    if ! "${cmd[@]}" >>"$WORK/spectacle-$mode.log" 2>&1; then
        die "spectacle: the $mode capture failed (spectacle exited non-zero). No PNG written."
    fi
    # Never trust the tool's exit code alone: a capture backend that reports success
    # and writes nothing is exactly how a zero-byte PNG gets published.
    if [ ! -s "$out" ]; then
        die "spectacle: the $mode capture produced no bytes. No PNG written."
    fi
}

# Sets CAPTURE_GEOMETRY to the WxH of a capture, and dies if the file is not a
# decodable image. A non-empty file is NOT proof of a usable capture.
#
# NOTE: this must set a global rather than print, because `die` inside a $( ... )
# would exit only the subshell and let the caller sail on with an empty geometry.
measure_capture() {
    local file="$1" mode="$2"
    local geom=""

    if ! geom="$(magick identify -format '%wx%h' "$file" 2>/dev/null)"; then
        die "magick: the $mode capture is not a decodable image ($file). No PNG written."
    fi
    geom="${geom%%$'\n'*}"
    if ! [[ "$geom" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]]; then
        die "magick: the $mode capture has a degenerate geometry ('$geom'). No PNG written."
    fi

    CAPTURE_GEOMETRY="$geom"
}

run_pass() {
    local mode="$1"
    local config="$WORK/config-$mode"
    local data="$WORK/data-$mode"
    local staged="$WORK/stage/$SURFACE-$mode.png"
    local theme

    theme="$(theme_for "$mode")"

    mkdir -p "$config/$APP_CONFIG_SUBDIR" "$data"
    write_settings "$mode" >"$config/$APP_CONFIG_SUBDIR/settings.json"

    printf 'pass %s: %s (settle %ss, window %s, theme %s)\n' \
        "$mode" "$BIN" "$SETTLE" "$WINDOW_SIZE" "$theme"

    XDG_CONFIG_HOME="$config" \
    XDG_DATA_HOME="$data" \
    ZED_WINDOW_SIZE="$WINDOW_SIZE" \
    ZED_WINDOW_POSITION="$WINDOW_POSITION" \
        "$BIN" "$FIXTURE_FILE" >>"$WORK/app-$mode.log" 2>&1 &
    APP_PID="$!"

    await_window "$mode"
    drive_surface
    capture_window "$staged" "$mode"
    measure_capture "$staged" "$mode"
    PASS_GEOMETRY+=("$mode=$CAPTURE_GEOMETRY")
    printf 'pass %s: captured %s\n' "$mode" "$CAPTURE_GEOMETRY"
    stop_app
}

# R5.1: the pair has to be diffable, which means both passes must have captured the
# same window at the same size. They cannot differ for any legitimate reason — the
# window bounds are pinned by env and the theme does not resize anything — so a
# mismatch means the fixture drifted, or `spectacle -a` grabbed a window that was
# not Zeo. Either way the pair is worthless, and a worthless pair must not be
# published: it would look perfectly plausible in the gate.
assert_pair_is_diffable() {
    local first="" entry geom

    for entry in "${PASS_GEOMETRY[@]}"; do
        geom="${entry#*=}"
        if [ -z "$first" ]; then
            first="$geom"
        elif [ "$geom" != "$first" ]; then
            die "fixture: the passes captured different geometries (${PASS_GEOMETRY[*]}) — the window drifted, or spectacle captured a window that was not Zeo. The pair would not be diffable. No PNG written."
        fi
    done
}

# --- Run both passes, then publish.

WORK="$(mktemp -d)"
FIXTURE_FILE="$WORK/$FIXTURE_DIR_NAME/$FIXTURE_FILE_NAME"
mkdir -p "$WORK/$FIXTURE_DIR_NAME" "$WORK/stage"
write_fixture >"$FIXTURE_FILE"

for appearance in light dark; do
    run_pass "$appearance"
done

assert_pair_is_diffable

# Publish only now: a pair is either whole or absent, never half-written.
mkdir -p "$OUT_DIR/$LABEL"
for appearance in light dark; do
    mv -f "$WORK/stage/$SURFACE-$appearance.png" "$OUT_DIR/$LABEL/$SURFACE-$appearance.png"
done

printf 'OK: %s/%s/%s-{light,dark}.png (active window, %s, themes %s / %s)\n' \
    "$OUT_DIR" "$LABEL" "$SURFACE" "${PASS_GEOMETRY[0]#*=}" "$THEME_LIGHT" "$THEME_DARK"
