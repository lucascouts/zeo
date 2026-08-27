---
story: zeo-visual-identity
type: feature
scale: full
version: 3
created: 2026-07-11
last-refined: 2026-07-13
history:
  - v1: Initial task plan
  - v2: Post-validation. Task 5 REOPENED — 5.1's palette left `border.variant` at 1.00:1
        against `elevated_surface`, so the hairline R2.1 demands does not exist on any of the
        71 re-skinned surfaces. New sub-task 5.4 moves the borders outside the ladder and
        asserts the R3.10 floors. The coverage grep at 4.1 and 7.2 is replaced with the
        per-corner-aware pattern (the old one is blind to `.rounded_tl_md()`, which is exactly
        what `button_like.rs` used). Quality Gates gain an explicit orphan-token waiver.
  - v3: Task 5 CLOSED (5.4/5.5, fork `e0de67d585` — all 16 border pairs now clear their floor).
        Task 1 REOPENED. Four user rulings at the run-mode gate:
        (a) `grim` is PROVABLY DEAD on this host (KWin has no `wlr-screencopy`), so the capture
            backend moves to `spectacle -a -b -n` — the fallback design.md already named. New
            sub-task 1.3 rewrites `shot.sh` AND the frozen `shot.test.sh` against it. This is a
            sanctioned edit of a frozen test's assertions: the user authorised it at the gate,
            which is exactly what the frozen-test rule's "STOP and escalate" exists to produce.
        (b) synthetic input is ENABLED (`sudo ydotoold`), so the five driven surfaces are
            capturable and R5.1 gets a genuinely identical fixture.
        (c) the visual evidence moves OUT of `.epic/` (the first line of .gitignore, which made
            the 1.2 and 7.4 commits silent no-ops) and into `docs/visual/`, where it is really
            versioned.
        (d) the brand art proceeds now.
        Sequencing note: 6.2 must land BEFORE the release rebuild, so ONE
        `RELEASE_CHANNEL=zeo` release build serves both 6.3 (icon validation) and 7.1 (the
        "after" captures) instead of two.
---

# Implementation Plan - Zeo Visual Identity

## Overview

Sequencing is driven by one irreversible constraint: **the "before" screenshots must be
captured before anything visual changes**, so the harness is Task 1, not Task 7. After
that: token substrate → the two pilots that consume it → the theme (independent, can run
in parallel) → the art (depends on the theme's accent) → the acceptance gate.

Test-first sub-tasks have their tests **pre-authored** under `.draft/authored-tests/`; the
executor materialises each to its real path and implements until Green.

**Red verification is split, deliberately.** `tests/shot.test.sh` is bash and lives in the
workspace, so it was **Red-verified at authoring time** (observed failure, recorded in
`.draft/red-evidence.yaml`). The four Rust tests could not be: in-crate unit tests require
a `mod` registration inside `fork/`, and writing there just to throw away a full debug
rebuild is waste. Each Rust test therefore carries a **header stating the exact Red the
executor must observe on materialisation**, and the executor's first act is to confirm that
Red before writing any implementation. Expected-Red is labelled as such in
`red-evidence.yaml` — never as observed.

Fork-side work happens in `fork/` (its own git repo, commits prefixed by crate, upstream
style); workspace-side work (scripts, shots, docs) happens in this repo (Conventional
Commits).

## Task List

- [x] 1 - Screenshot harness and baseline capture  ⚠ **REOPENED at v3 — closed by 1.3/1.2**
  - _Complexity: Simple | Tests: Integration (pre-authored) | Risks: `slurp` absent — no interactive region; an unreproducible fixture makes every later pair worthless | Dependencies: None_
  - Objective: comparable before/after pairs, and the "before" half banked before any pixel moves.
  - ⚠ **EXECUTION ORDER AT v3 IS `1.3 → 1.2`**, not the numeric order. 1.3 repairs the capture
    backend that 1.2 depends on. Sub-tasks are never renumbered (the deviation register and the
    Task 7 rows both reference "1.2" by number), so the new work is appended and the order is
    stated here instead.

  - [x] 1.1 - `scripts/shot.sh` (test-first)
    - Context:
      - Files: `.draft/authored-tests/tests/shot.test.sh` (READ FIRST — it pins the contract), `docs/BUILD.md` (the build invocation the script must reuse)
    - Objective: a reproducible capture of a fixed fixture, in both appearances.
    - ToDo: materialise the authored test to `tests/shot.test.sh` and re-confirm Red;
      implement `scripts/shot.sh` with args `--label <before|after>` and
      `--surface <name>`: launch `target/release/zeo` against a **throwaway config dir**
      (never the user's `~/.config/zeo`), force the appearance (light and dark passes),
      open a fixed fixture file, wait for the window, capture with `grim`, crop against
      fixed coordinates with `magick`, emit to
      `.epic/stories/002-visual-identity/shots/<label>/<surface>-<mode>.png`.
      GOTCHA: `slurp` is absent — there is no interactive region selection. Capture the
      full output and crop; that is why the fixture (window size, open file, panel layout)
      must be pinned in the script, not chosen at run time.
      On launch failure, exit non-zero naming the step and leave no stray window.
      Shell rules: `set -euo pipefail`, quoted expansions, arrays for args.
    - Tests: Integration · `tests/shot.test.sh` — a run with a stub binary produces the
      expected file tree; both appearances captured; a missing `grim` fails loudly rather
      than emitting a zero-byte PNG; a failed launch leaves no partial output
    - Validation: `bash tests/shot.test.sh` passes; `shellcheck scripts/shot.sh` clean
      (GOTCHA from 001: shellcheck is absent on this host — suggest `dev-util/shellcheck`;
      do not install without authorization)
    - Requirements: R5.1, R5.2
    - Commit: "feat: screenshot harness for visual acceptance"

  - [x] 1.2 - Capture the "before" baseline  *(amended at v3 — runs AFTER 1.3)*
    - ✅ Done (workspace `d85d58f`). Six surfaces × two appearances, all 1600x900, captured
      from the banked binary. Four are elevated surfaces (command palette, file picker,
      outline, theme selector) — the ground the chokepoint re-skins; `project-search` brings
      Task 4's toggle row along. **Every PNG was inspected by eye, not accepted on exit code**
      — see the locked-session discovery, which is exactly why.
    - Objective: bank the pre-change state.
    - ToDo: **do NOT rebuild, and do NOT check out the pre-002 commit.** Run `shot.sh --label
      before` against the **banked pre-change RELEASE binary** at
      `.epic/stories/002-visual-identity/baseline-bin/zeo`, across the surfaces the pilots
      touch: command palette, file picker, a popover, a modal, the button/toggle row, and the
      editor at rest — in both light and dark, passing `--keys` explicitly for every driven
      surface.
      **GOTCHA — why the v1 "irreversible" warning is void, and why that is not luck.**
      `rust-embed` is used WITHOUT the `debug-embed` feature (`crates/assets/src/assets.rs`),
      so a RELEASE build **embeds `assets/themes/**` into the binary**. The banked binary
      therefore renders the pre-change (Zed / One Dark) appearance **permanently**, no matter
      what the source tree does afterwards. The "before" is reproducible on demand. Pass
      `--theme-light 'One Light' --theme-dark 'One Dark'` (the script's defaults) for this pass.
    - Validation: `docs/visual/shots/before/` contains a light and a dark PNG per surface,
      non-zero bytes, each showing the *pre-change* (Zed) appearance.
    - Requirements: R5.1
    - Commit: workspace — "chore: bank pre-change visual baseline" *(v3: now a REAL commit —
      the evidence lives in `docs/visual/`, not under the gitignored `.epic/`)*

  - [x] 1.3 - Swap the capture backend to `spectacle` (NEW at v3)
    - ✅ Done (workspace `c51f0c8`, hardened by `7ea786b`). Suite 4 scenarios/17 checks →
      **10/71**, shellcheck clean. Two silent-failure holes closed beyond the brief: a LOCKED
      session (which returns a correctly-sized, decodable, BLANK PNG that every downstream
      guard waves through — caught only by accident, after two innocent causes were blamed
      first) and Zed's trust modal (which HOLDS FOCUS, so every `--keys` chord would have
      driven the modal instead of the editor and corrupted all five driven surfaces under the
      right filenames). Both are now preflight failures, before any window is launched.
    - Context:
      - Files: `scripts/shot.sh` (10 `grim` references), `tests/shot.test.sh` (**17** `grim`
        references, including an entire `no-grim` scenario mode — READ FIRST), `docs/BUILD.md`
    - Objective: a capture backend that actually captures on this host.
    - ToDo: **`grim` is PROVABLY DEAD here** — `grim -g '0,0 1x1' out.png` returns *"compositor
      doesn't support the screen capture protocol"*, exit 1, no file. KWin does not implement the
      `wlr-screencopy` protocol grim requires. Every real `shot.sh` run fails at the capture step.
      The harness is not broken; its backend is.
      Rewrite `shot.sh` and `tests/shot.test.sh` against **`spectacle -a -b -n -o <file>`**
      (`--activewindow --background --nonotify`). design.md §9 **already names spectacle as the
      intended fallback**; only the pre-authored test did not know.
      **This is STRICTLY BETTER than what the plan designed, not a concession.** `-a` captures the
      **active window directly**, which deletes the fixed-coordinate `magick` crop *and* the
      reason `slurp`'s absence ever mattered. R5.1's "identical fixture" guarantee gets *easier*:
      a window-scoped capture cannot drift with screen resolution or panel layout.
      Also move the output root from `.epic/stories/002-visual-identity/shots/` to
      **`docs/visual/shots/`** (v3 ruling (c) — `.epic/` is gitignored, so the old path made the
      1.2 and 7.4 commits silent no-ops).
      **AUTHORISED EDIT OF A FROZEN TEST.** `tests/shot.test.sh`'s assertions pin `grim`. Rewriting
      them is behaviour-changing and would normally be forbidden — the user authorised it at the
      run-mode gate, which is precisely what the frozen-test rule's "STOP and escalate" exists to
      produce. Preserve every scenario's *intent*, and re-derive only what the backend swap forces:
      the `no-grim` mode becomes `no-spectacle`; the "missing tool fails loudly, emits no zero-byte
      PNG" contract is **unchanged and must survive**.
      **GOTCHA — the latent bug in the test being replaced.** Scenario s2 ("`grim` missing → loud
      failure") passes today for a HOST-SPECIFIC and WRONG reason: its shim dir omits `grim`, but
      `PATH` still contains `/usr/bin`, so the script finds the REAL grim — which exits non-zero
      only because KWin cannot screencopy. On a wlroots host that scenario would go RED. **Fix this
      while rewriting**: the shim must make the tool genuinely unreachable (prepend the shim dir and
      strip the system paths), not rely on the host's backend being broken.
      Shell rules: `set -euo pipefail`, quoted expansions, arrays for args, `shellcheck` clean
      (shellcheck IS installed — the stale story-001 note saying otherwise is retracted in the
      deviation register).
    - Tests: Integration · `tests/shot.test.sh` — rewritten. Same contract as v1, new backend: a run
      with a stub binary produces the expected file tree under `docs/visual/shots/`; both appearances
      captured; a **missing `spectacle`** fails loudly rather than emitting a zero-byte PNG (and the
      shim must genuinely hide it — see the GOTCHA); a failed launch leaves no partial output and no
      stray window; a driven surface requested with no usable input backend exits non-zero **before**
      launching.
    - Validation: `bash tests/shot.test.sh` passes; `shellcheck scripts/shot.sh` clean; and — the
      row the old harness could never satisfy — **one real capture against the banked baseline
      binary produces a non-zero PNG that visibly shows a Zeo window.**
    - Requirements: R5.1, R5.2
    - Commit: workspace — "fix: capture through spectacle; KWin cannot screencopy"

- [x] 2 - Zeo token substrate
  - _Complexity: Moderate | Tests: Unit (pre-authored) | Risks: the `ui_font_size` formula trap; `UiDensity::spacing_ratio` is dead code that looks live | Dependencies: None_
  - Objective: settings-resolved tokens that stories 003 and 006 can build on without a rewrite.

  - [x] 2.1 - Extend `ThemeSettingsProvider` + the `zeo` settings namespace
    - Context:
      - Files: `fork/crates/theme/src/theme_settings_provider.rs:9-24,34-43` (the trait + global, churn 1), `fork/crates/theme_settings/src/theme_settings.rs:43-65,75,104-161` (the impl, its registration, and the `SettingsStore` observer that gives live reload for free)
    - Objective: one hook that every Zeo token reads from, and that story 006 hangs its knobs on.
    - ToDo: add the Zeo token accessors to the `ThemeSettingsProvider` trait; implement on
      `ThemeSettingsProviderImpl`; add the `zeo` settings group carrying **one concrete
      knob — `zeo.radius_scale: f32`, default `1.0`** (D23), a multiplier the radius token
      applies to every step.
      **Clamp `radius_scale` to 0.5–2.0** (D23): an out-of-range value is clamped, not
      rejected. `0` would square every corner in the app and `1000` is a rendering
      pathology — and this is a user-editable JSON file. Story 006 must inherit a validated
      knob, not a raw `f32`.
      **GOTCHA: do not ship an "empty defaults" namespace.** A settings group with zero
      fields is untestable and unfalsifiable — it would be exactly the orphan-code failure
      the Quality Gate forbids. One real knob makes the hook provable and hands story 006
      a working token→knob mapping to extend.
      GOTCHA: `theme_settings(cx)` **panics** if no provider is registered
      (`theme_settings_provider.rs:40`) — tokens must never be read outside a rendering
      context. Not a new failure mode; the existing spacing tokens share it (R1.6).
      No `unwrap()`/`expect()` in new code.
    - Tests: Unit · `fork/crates/theme_settings/` — writing `zeo.radius_scale` changes the
      **value the provider returns**.
      ⚠ **Do NOT assert "live reload fires"**: `SettingsStore` already calls
      `cx.refresh_windows()` on *any* settings change
      (`fork/crates/settings/src/settings_store.rs:400`), so a render-count assertion goes
      green against an implementation that wired nothing at all. Assert the returned value.
    - Validation: `cd fork && cargo test -p theme_settings -p theme` passes.
    - Requirements: R1.1, R1.5, R1.6, R1.7

  - [x] 2.2 - Radius token module (`crates/ui/src/styles/radius.rs` — NEW)
    - Context:
      - Files: `fork/crates/ui_macros/src/dynamic_spacing.rs:146-162` (READ FIRST — the formula to mirror), `fork/crates/ui/src/styles.rs` (registration, churn 0), `fork/crates/ui/src/components/avatar.rs:224` (proves `.rounded(len)` with an argument exists)
    - Objective: the scale 0/2/4/6/8/12/16/full, resolved through `&App`.
    - ToDo: new file exposing the scale with `px(&self, cx: &App) -> Pixels` and
      `rems(&self, cx: &App) -> Rems`, multiplied by `zeo.radius_scale` (D23).
      Register with 2 lines in `styles.rs` (`mod radius;` + `pub use radius::*;`).
      **No per-corner token surface is needed** — GPUI's `rounded_tl/tr/br/bl` already take
      a `Pixels` argument (`gpui_macros/src/styles.rs:1206`), so `button_like.rs` writes
      `.rounded_tl(ZeoRadius::Md.px(cx))` against the plain token. Do not build an API 4.1
      will not use.
      **GOTCHA: `DynamicSpacing::px(cx)` is `ui_font_size × ratio`, NOT `16 × ratio`**
      (`dynamic_spacing.rs:159-162`). A radius that hard-codes 16 will silently drift away
      from spacing the moment a user changes `ui_font_size`. Mirror the formula, or return
      `rems` and let GPUI's `rem_size` scale it.
      **GOTCHA: radius is density-INVARIANT (D21)** — unlike `DynamicSpacing`, there is no
      density triple. Density governs the air *between* elements, not the shape *of* one: a
      6px button must stay 6px at Comfortable. Do not copy `DynamicSpacing`'s triple shape.
      **GOTCHA: `Full` is a fixed sentinel (D22)** — `9999 × (ui_font_size / 16)` is
      meaningless. It is exempt from the scaling every other step obeys.
      **GOTCHA: do NOT build on `UiDensity::spacing_ratio()`** (`theme/src/ui_density.rs:37`).
      It looks like the density hook but `DynamicSpacing` does not use it, and upstream
      marks it `TODO: Standardize usage throughout the app or remove`.
    - Tests: Unit · `fork/crates/ui/` — each step resolves to the expected `Pixels` across
      **two different `ui_font_size` values** (a single-value test passes on the broken
      implementation — this is the whole point); the scale is **density-invariant**; `Full`
      does not scale; `zeo.radius_scale` multiplies every step; the scale is strictly
      monotonic; and `outer − padding` lands on the scale for the four nested cases,
      **computed against the real `DynamicSpacing` values, not hard-coded padding
      literals** — otherwise the closure test pins nothing (D5 requires re-verification
      against *both* scales)
    - Validation: `cd fork && cargo test -p ui` passes; `./script/clippy` clean on `ui`.
    - Requirements: R1.1, R1.2, R1.3, R1.4, R1.7, R1.8

  - [x] 2.3 - Commit
    - Validation: `cd fork && cargo check` (workspace) passes.
    - Commit: fork — "theme: expose Zeo design tokens through the settings provider" +
      "ui: add the Zeo corner-radius token scale"

- [x] 3 - Elevation and the chokepoint (Pilot 1)
  - _Complexity: Moderate | Tests: Unit | Risks: churn is low (0-12), but the blast radius is 55 call sites across 45 files — a mistake here is visible everywhere at once; adding a ThemeColors field regenerates the Refineable/schema derives | Dependencies: Task 2_
  - Objective: fix all three depth defects and re-skin every elevated surface.

  - [x] 3.0 - New theme colour `modal_surface_background` (D25)
    - Context:
      - Files: `fork/crates/theme/src/styles/colors.rs:29-33` (the `*_background` fields; `ThemeColors` is `#[derive(Refineable, ...)]`, churn 6), `fork/crates/settings_content/src/theme.rs` (the JSON schema, churn 12), `fork/crates/ui/src/styles/elevation.rs:89-90` (where both `ElevatedSurface` and `ModalSurface` return `elevated_surface_background`)
    - Objective: give `e3` a colour to step to — without it, D7's four-level ladder is unrepresentable.
    - ToDo: add `modal_surface_background: Hsla` to `ThemeColors`; expose it in the theme
      JSON schema; point `ElevationIndex::ModalSurface` at it.
      **GOTCHA: every existing theme leaves the new field unset.** The fallback must
      resolve to `elevated_surface_background`, preserving today's appearance for One,
      Ayu, Gruvbox and every user theme. **A wrong default renders a black modal in every
      Zed theme** — this is the failure mode to guard.
    - Tests: Unit · `fork/crates/theme/` — a theme with the field unset falls back to
      `elevated_surface_background`; a theme that sets it resolves to that value
    - Validation: `cd fork && cargo test -p theme -p theme_settings` passes; One/Ayu/Gruvbox
      render unchanged.
    - Requirements: R2.1, R2.3

  - [x] 3.1 - Re-model elevation
    - Context:
      - Files: `fork/crates/ui/src/styles/elevation.rs:14-117` (the enum; `shadow()` :42-77 with its hardcoded `BoxShadow` vecs; `Surface`/`EditorSurface` return `vec![]` at :46-47), `fork/crates/gpui/src/style.rs:345-356` (`BoxShadow.inset` — this is what makes the rim possible)
    - Objective: separation by background step + hairline first; shadow only for e2/e3; an inset rim on the top edge.
    - ToDo: implement the four-level model from design.md §Elevation. Add a `rim()`
      accessor returning the inset `BoxShadow`. Keep Zed's existing `e2`/`e3` shadow stacks
      (peak alpha 12%) — they are already correct.
      **GOTCHA: `Surface` and `EditorSurface` returning `vec![]` is deliberate upstream
      design, not an oversight** (`:46-47`). The fix for flatness is the **background step
      and the rim**, never adding a shadow there.
      **GOTCHA: never reach for GPUI's `.shadow_sm/md/lg/xl()`** — they are a verbatim
      Tailwind port at 10-25% alpha (`gpui_macros/src/styles.rs:390-488`) and are exactly
      the dated baseline this story exists to leave (R2.3).
    - Tests: Unit · `fork/crates/ui/` — every `ElevationIndex` resolves in both
      appearances; peak shadow alpha ≤ 12%; `e2`/`e3` carry an inset shadow, `e0`/`e1` do
      not.
      ⚠ **This test CANNOT assert the background luminance step (R2.1), and no test in
      `crates/ui` can.** `ElevationIndex::bg()` returns `elevated_surface_background`
      straight from the *active theme* (`elevation.rs:89-90`), and a `ui` unit test runs
      against the base themes — One Dark — where `elevated_surface == surface` **by data**.
      The step is asserted only in Task 5.1, against the Zeo theme. This side tests the
      *mechanism*; the theme side tests the *values*. Do not "fix" this by writing a
      cleverer unit test — it is a structural constraint, not an oversight.
    - Validation: `cd fork && cargo test -p ui` passes.
    - Requirements: R2.4, R2.5

  - [x] 3.2 - Convert the chokepoint (`traits/styled_ext.rs`)
    - Context:
      - Files: `fork/crates/ui/src/traits/styled_ext.rs:6-18` (`elevated` and `elevated_borderless` — churn 0; they back `elevation_1/2/3`, used at 55 call sites across 45 files)
    - Objective: re-skin pickers, command palette, popovers, modals, context menus and toasts without touching a single call site.
    - ToDo: **call `index.bg(cx)`** (D24 — see the GOTCHA below); replace `.rounded_lg()`
      with the Zeo radius token; wire in the border + rim + shadow from 3.1. Signatures
      stay unchanged.
      **GOTCHA — THE THIRD DEFECT (D24), and the reason the other two were not enough.**
      Both helpers currently **hard-code** the background and use `index` **only** for the
      shadow:
      ```rust
      this.bg(cx.theme().colors().elevated_surface_background)  // <- NOT index.bg(cx)
          .rounded_lg().border_1()
          .shadow(index.shadow(cx))                            // <- index used only here
      ```
      So `elevation_1`, `elevation_2` and `elevation_3` all paint the **same** background,
      and `ElevationIndex::bg()` is dead code — called from nowhere in `crates/ui`.
      **Fixing the palette (Task 5.1) accomplishes nothing until this calls `index.bg(cx)`**,
      because the helper never asks the enum which step it is on.
      **GOTCHA: elevated surfaces do NOT set their radius at the call site.** Grepping
      `.rounded_` in `crates/picker`, `crates/command_palette` and `crates/notifications`
      returns **zero hits**, which will lead you to conclude those surfaces have no radius.
      They inherit it from here. **Patch these two helpers, never the 45 call sites**
      (R2.4).
    - Tests: Unit · `fork/crates/ui/` — **`elevated()` and `elevated_borderless()` are
      asserted directly**: apply each to a `div()` and inspect the resulting
      `StyleRefinement` for the border width, the corner radius sourced from the Zeo token,
      the inset rim, and — **the assertion that pins D24** — that the background equals
      **`index.bg(cx)`**, differing across `elevation_1` / `_2` / `_3`. A weaker
      `background.is_some()` assertion passes against today's broken helper and must not be
      accepted.
      ⚠ This test was **missing from the first draft of this plan**, which claimed 3.2 was
      "covered by 3.1 + the grep". It was not: 3.1 exercises the `ElevationIndex` *enum*,
      and the grep proves only the *absence* of literals. Neither asserts that this
      function applies anything at all — and it is the one function that re-skins 55 call
      sites. **R2.1's mechanism half and R2.2 live or die here.**
    - Validation: `cd fork && cargo test -p ui` passes; `cargo build -p ui` passes;
      `git diff --stat` shows only `styled_ext.rs` and `elevation.rs` touched — **zero call
      sites modified**.
    - Requirements: R2.2, R2.4, R2.6, R1.2

  - [x] 3.3 - Commit
    - Validation: `cd fork && cargo check` (workspace) passes; `./script/clippy` clean.
    - Commit: fork — "ui: separate elevated surfaces by step, hairline and rim light"

- [x] 4 - Control pilots (Pilot 2)
  - _Complexity: Simple | Tests: Unit | Risks: the coverage grep proves literals are gone, never that the RIGHT step arrived | Dependencies: Task 2_
  - Objective: prove the token on directly-styled components; cover every button and toggle in the app.

  - [x] 4.1 - Convert `button_like.rs` and `toggle.rs`
    - Context:
      - Files: `fork/crates/ui/src/components/button/button_like.rs:753-756` (per-corner: `rounded_tl/tr/br/bl_sm`), `fork/crates/ui/src/components/toggle.rs:232,247,473,499,510` (both churn 3)
    - Objective: zero radius literals left in either file, and the **right** step in place.
    - ToDo: replace every `.rounded_*()` literal with the Zeo radius token, holding
      controls at the `md` (6px) step per design.md §Radius.
      **No per-corner token API is needed** — GPUI's `rounded_tl/tr/br/bl` already take a
      `Pixels` argument (`gpui_macros/src/styles.rs:1206`), so write
      `.rounded_tl(ZeoRadius::Md.px(cx))` against the plain token from 2.2. Do not build,
      or ask for, a per-corner token surface.
    - Tests: Unit · `fork/crates/ui/` — a rendered `ButtonLike` and a rendered `Toggle`
      carry the corner radius resolved from **`ZeoRadius::Md`**, in every corner.
      ⚠ **The coverage grep alone is not a test.** `grep -c '.rounded_*()' == 0` passes
      just as happily if every button was converted to `ZeoRadius::Full` — it proves the
      literals are *gone*, never that the *right step* arrived. Given design.md's own
      counter-rule ("do not over-round — a 10px button reads 'web app in a window'"), the
      single thing 4.1 can get wrong is the single thing the grep cannot see.
    - Validation: `cd fork && cargo test -p ui` passes;
      `grep -cE '\.rounded_((tl|tr|br|bl)_)?(xs|sm|md|lg|xl|2xl|3xl|full)\(\)'` returns **0**
      for both files.
      ⚠ **v2 — the v1 pattern was `\.rounded_(xs|sm|...)\(\)` and it is BLIND to the
      per-corner forms** (`.rounded_tl_md()` etc.) — which are precisely what
      `button_like.rs:753-756` used. It returned 0 against a file still full of literals.
      Found by the 4.1 Executor's own mutation proof: re-introducing the literals left the
      official grep at 0 and only the unit test went red. **Use the corrected pattern above
      everywhere, including the 7.2 gate row.**
    - Requirements: R2.7, R1.2

  - [x] 4.2 - Commit
    - Validation: `./script/clippy` clean on `ui`.
    - Commit: fork — "ui: read button and toggle radius from the Zeo token"

- [x] 5 - Zeo theme family  ⚠ **REOPENED at v2 — closed by 5.4/5.5** (fork `e0de67d585`)
  - _Complexity: High | Tests: Integration (pre-authored) | Risks: a name mismatch falls back to One Dark **silently**; syntax harmonisation is the subjective part | Dependencies: Task 3 (5.1 must SET `modal_surface.background`, the field 3.0 adds — the v1 header's "None (parallel with 2-4)" was false; recorded in the deviation register)_
  - Objective: the Zeo palette — and the two research defects fixed in data.

  - [x] 5.1 - Author `assets/themes/zeo/zeo.json`
    - Context:
      - Files: `fork/assets/themes/one/one.json` (the shape to follow, and the source of the derived syntax palette), `fork/crates/settings_content/src/theme.rs:473-491` (`ThemeStyleContent` — proves the JSON carries **colour only**, no geometry)
    - Objective: family "Zeo" with variants "Zeo Dark" and "Zeo Light".
    - ToDo: author both variants. **The two defects must be fixed in the data**:
      `text.accent` = `#BD93F9` (dark) / `#7C3AED` (light), **distinct from `info`** (today
      they are byte-identical — `one.json:34`=`:128`, `:448`=`:540`); and
      `elevated_surface.background` **distinct from** `surface.background` (today identical
      — `one.json:16`=`:17`, `:430`=`:431`), following the luminance ladder approved in
      design.md §Elevation. Derive `syntax` from One Dark and harmonise its highlights with
      the Amethyst accent — do **not** author a syntax palette from scratch (R3.8).
      No code change is needed to register it: themes are embedded by directory glob
      (`crates/assets/src/assets.rs:7-13`) and discovered by listing.
    - Tests: Integration · `fork/crates/theme_settings/` — `zeo.json` deserialises into
      `ThemeFamilyContent`; both variants register; **`text.accent != info`** and
      **`elevated_surface.background != surface.background`** in both variants; the accent
      clears WCAG AA (≥4.5:1) against the editor background in both variants.
      ⚠ **This is the ONLY place the background luminance step (R2.1) can be asserted.** No
      test in `crates/ui` can do it — `ElevationIndex::bg()` reads the *active theme*, and a
      `ui` unit test gets One Dark, where elevated == surface by data. The depth fix is a
      **data** claim, and this is the test that carries it.
    - Validation: `cd fork && cargo test -p theme_settings` passes; the app lists "Zeo
      Dark" and "Zeo Light" in the theme selector.
    - Requirements: R2.1, R3.2, R3.3, R3.4, R3.5, R3.8

  - [x] 5.2 - Flip the default theme
    - Context:
      - Files: `fork/assets/settings/default.json:9-13` (the `theme` block — file churn 154/6mo, but **line churn 0**)
    - Objective: Zeo opens as Zeo.
    - ToDo: set `"light": "Zeo Light"`, `"dark": "Zeo Dark"`; keep `"mode": "system"`.
      Two lines. No channel conditional — the Zeo binary is always channel `zeo`
      (`release_channel/src/lib.rs:146,217`), so a channel check would be dead code (D12).
      **GOTCHA: the theme is keyed by the `name` field INSIDE the JSON, not by the
      filename.** If the string here does not match it exactly, the app **silently falls
      back to One Dark** and only logs — after extensions load
      (`theme_settings.rs:171-181`). This is the single most likely way to ship a Zeo build
      that looks like Zed and never notice. The test in 5.1 must assert the two strings are
      equal (R3.6).
    - Tests: Covered by Task 5.1 (name coherence)
    - Validation: a fresh launch with a throwaway config dir opens in Zeo Dark; every Zed
      theme is still selectable (R3.7).
    - Requirements: R3.1, R3.6, R3.7

  - [x] 5.3 - Commit
    - Validation: `cd fork && cargo test -p theme_settings` passes.
    - Commit: fork — "theme: add the Zeo theme family and make it the default"

  - [x] 5.4 - Move the border tokens outside the surface ladder (NEW at v2)
    - Context:
      - Files: `fork/assets/themes/zeo/zeo.json` (the four hexes below),
        `fork/crates/theme_settings/tests/zeo_theme.rs` (READ FIRST — extend it; the
        frozen-test rule applies to its EXISTING assertions, and adding new ones is
        permitted), `fork/crates/ui/src/traits/styled_ext.rs:43` (proof that the chokepoint
        paints `border_variant`, which is why this is not a cosmetic nit)
    - Objective: a hairline that exists at every rung — R2.1's second depth cue, which today
      is absent on all 71 re-skinned surfaces.
    - ToDo: **THIS IS A REGRESSION 5.1 INTRODUCED, not a pre-existing Zed defect.** Upstream
      One Dark's ladder is *flat* (`surface == elevated`), so one fixed `border.variant` sat
      consistently above all of it. 5.1 created the ladder and left the border where it was —
      so `border.variant` `#403d4d` is now *lighter* than e1, **byte-adjacent to e2**
      (`#403d4f` → **1.00:1**), and *darker* than e3. It crosses the ladder instead of
      clearing it, and vanishes exactly at the elevated surface.
      Apply these four values (hue and saturation preserved; both floors of R3.10 met with no
      margin wasted):

      | token | Zeo Dark | Zeo Light |
      |---|---|---|
      | `border` | `#524f62` → **`#636077`** | `#cecbd8` → **`#b9b4c7`** |
      | `border.variant` | `#403d4d` → **`#58546a`** | `#e4e3eb` → **`#c8c6d7`** |

      **GOTCHA: keep the two tokens distinct.** A single shared floor drives both to the same
      colour (`#636077` vs `#646079` — I checked) and destroys the prominence hierarchy that
      **162** `border` and **127** `border_variant` call sites consume. Two floors, on purpose.
      **GOTCHA: `zeo.json` must stay STRICT JSON** — the bundled loader is
      `serde_json::from_slice` (`theme_settings.rs:242`), not the lenient parser the test
      uses. A comment or trailing comma passes the suite and then fails **silently** in the
      app, falling back to One Dark. Verify with `jq empty`.
      **GOTCHA: do NOT "fix" this by raising the floors to 3:1.** That was R3.5's v1 wording,
      it over-reached WCAG 1.4.11 (which governs focus rings and UI components, not surface
      separators — and `border.focused` already clears it at 3.77–5.81:1), and it contradicts
      design.md principles 1 and 10. The hairline stays low-contrast; it just has to *exist*.
    - Tests: Integration · `fork/crates/theme_settings/tests/zeo_theme.rs` — a new
      `#[gpui::test]` sweeping **2 border tokens × 4 surface rungs × 2 variants = 16 pairs**,
      asserting `border` ≥1.5:1 and `border.variant` ≥1.25:1 (R3.10); plus a
      `border.focused` ≥3:1 sweep over the same rungs (R3.9).
      ⚠ **Prove it non-vacuous by mutation**: restore `border.variant` to `#403d4d` and the
      new test MUST go red at the `elevated_surface` pair with a ratio of 1.00. If it stays
      green, the test is measuring the wrong thing — it is asserting against the *rung* it
      happens to clear rather than against *every* rung.
      ⚠ This is the ONLY place R3.9/R3.10 can be asserted — same structural reason R2.1's
      luminance step can only live here: `crates/ui` tests run against One Dark, whose ladder
      is flat and whose borders are a different palette entirely.
    - Validation: `cd fork && cargo test -p theme_settings` passes; `jq empty` clean on
      `zeo.json`; the 16-pair sweep is green and its mutation is red.
    - Requirements: R2.1, R3.9, R3.10

  - [x] 5.5 - Commit (NEW at v2)
    - Validation: `cd fork && cargo test -p theme -p theme_settings -p ui` passes;
      `./script/clippy` clean on the touched crates.
      ✅ 150 tests green (theme 4, theme_settings 18 + 10 integration, ui 79 + 39 doc-tests),
      real cargo exit 0; `./script/clippy -p theme_settings` exit 0 under `-D warnings`;
      `jq empty` clean on `zeo.json`.
    - Commit: fork — "theme: move the Zeo borders outside the surface ladder" (`e0de67d585`)

- [ ] 6 - Brand art
  - _Complexity: Moderate | Tests: None (manual validation — three silent failure modes) | Risks: the art can appear not to apply for three independent reasons, none of which is an error message | Dependencies: Task 5 (the accent is the art's source palette)_
  - Objective: replace 001's placeholder with final art derived from the Zeo accent.

  - [x] 6.1 - Explore directions
    - ✅ Four directions generated with `nanobanana` (faceted crystal cluster / refracting
      prism / brilliant-cut gem / faceted Z), each judged at a REAL 32px downscale rather
      than at 512 — which is what separated them: the gem regressed at small size (finer
      facets turn to noise) and the prism, the strongest concept, had a composition that
      bled off the tile. **User chose the crystal cluster.** Explorations kept under
      `art-directions/` (gitignored — they are provenance, not product).
    - Objective: a chosen visual direction, approved before any final drawing.
    - ToDo: use `nanobanana` to generate several directions around *faceted crystal /
      gemstone / prism*, in the Amethyst palette. Present them; the user picks one.
      **GOTCHA (trademark, R4.2):** the art may be **evocative** but never **derivative** —
      no Power Rangers logotype, no Zeo Crystal shape or colourway as depicted in the
      franchise, no character or ranger iconography, no lightning-bolt-Z lockup. Power
      Rangers is a Hasbro property and Zeo is a publicly downloadable product. This is the
      same rule story 001 wrote against Zed's mark, applied symmetrically.
    - Validation: the user has selected a direction.
    - Requirements: R4.2, R4.4

  - [x] 6.2 - Draw the final art and swap in place
    - ✅ `fork/crates/zed/resources/zeo-icon.svg` (source, provenance + symmetric trademark
      posture stated in-file) generated by `scripts/build-icon.py` — **constructed, not
      traced**: a parametric crystal model (hexagonal prism + pyramidal tip, isometric,
      painter-ordered). All four PNGs replaced in place at their existing dimensions;
      checksums moved `72648b…` → `ca89f9…`, weight 204KB → 34KB.
      The palette is DERIVED from the accent, not matched to it: the two middle steps of the
      five-step ramp ARE the brand hexes (`#BD93F9` / `#7C3AED`).
      Three findings the real-size test forced, all recorded in the deviation register: a long
      tip reads as a CROWN, not a cluster (proportion, not colour); the near-white tip facet
      vanishes on a light panel without a tile; and the first tile shipped the very bug it
      existed to prevent — its field sat at the same value as the crystal's shadow facets, so
      the shafts dissolved and the tips floated free.
    - Context:
      - Files: `docs/REBRAND.md:22-27` (the exact asset inventory), `fork/crates/zed/resources/` (the targets)
    - Objective: crisp vector art at every size, replacing the placeholder with zero rebase surface.
    - ToDo: redraw the chosen direction as a clean **geometric SVG** (committed as source,
      authorship stated — R4.2); export to PNG and replace **in place**, same filenames and
      sizes: `crates/zed/resources/app-icon-zeo.png` (512),
      `app-icon-zeo@2x.png` (1024),
      `crates/zed/resources/zeo/hicolor/{512x512,1024x1024}/apps/dev.zeo.Zeo.png`.
      The placeholder's measured baseline for comparison: mean luminance 0.85, contrast
      14.5:1 against a KDE dark panel, dominant colours `#291B73`→`#35AFC8`. **Note the
      defect is not contrast — it is form**: a flat two-tone "Z" with no depth, in a hue
      family that harmonises with no viable accent. Do not "fix" it by raising contrast.
      Verify legibility at 32px, not just at 512.
    - Validation: the SVG source is committed; all four PNGs replaced; `identify` reports
      the expected dimensions.
    - Requirements: R4.1, R4.2, R4.4

  - [ ] 6.3 - Validate the installed icon
    - Objective: prove the art actually reaches the running window — against three silent failure modes.
    - ToDo: rebuild **with `RELEASE_CHANNEL=zeo` set**, reinstall, rebuild the KDE caches,
      relaunch, and confirm visually.
      **GOTCHA 1:** the window icon is chosen at **build time** by `build.rs` from the
      `RELEASE_CHANNEL` **environment variable** — a *different* mechanism from the
      `crates/zed/RELEASE_CHANNEL` **file** that drives the runtime enum
      (`docs/BUILD.md:37`). Rebuilding without it yields the **dev icon**, and you will
      conclude the art did not apply.
      **GOTCHA 2:** KDE caches — the icon does not appear until `kbuildsycoca6` **and**
      `gtk-update-icon-cache` are run (`docs/REBRAND.md:85-89`). A missing icon is almost
      always a stale cache, not a wrong app_id.
      **GOTCHA 3:** `hicolor/index.theme` declares sizes only up to `512x512/apps` — the
      1024px asset is a **master and is never resolved by icon-theme lookup**
      (`docs/REBRAND.md:87-89`). Do not "verify" against it.
    - Validation: the checksum of the **installed** icon file has changed **and** the
      running window visibly shows the new art after a cache rebuild — never "I replaced
      the PNG" (R4.3).
    - Requirements: R4.3

  - [ ] 6.4 - Commit
    - Validation: `desktop-file-validate` still passes; icon filenames still equal the
      app_id `dev.zeo.Zeo`.
    - Commit: fork — "zed: final Zeo brand art"; workspace — "docs: record the art
      provenance and trademark posture" (adds the symmetric Hasbro rule to `REBRAND.md`,
      which today defends only against Zed)

- [ ] 7 - Acceptance and gate
  - _Complexity: Simple | Tests: Covered by Tasks 1-5 | Risks: none | Dependencies: Tasks 1, 3, 4, 5, 6_
  - Objective: the falsifiable gate from design.md §Testing — four rows that can each say no.

  - [ ] 7.1 - Capture the "after" pairs and compose  *(amended at v3)*
    - ToDo: run `shot.sh --label after` over the same surfaces, the same fixture and the same
      `--keys` chords as 1.2; compose before/after pairs with `magick`. Any surface whose fixture
      drifted is invalid — recapture, do not eyeball.
      **v3 — the "after" pass runs against the RELEASE build produced for 6.3**, not a debug
      build and not a second build: 6.3 and 7.1 both need `RELEASE_CHANNEL=zeo cargo build
      --release`, and one build serves both. This is why 6.2 is sequenced before it.
      **GOTCHA: pass `--theme-light 'Zeo Light' --theme-dark 'Zeo Dark'` explicitly.** The script
      defaults to the stock `One Light`/`One Dark` names (it pins theme NAMES, not just the
      appearance `mode` — `ThemeSelection` is `#[serde(untagged)]` and its `Dynamic` variant
      requires both keys, so a settings file carrying only `mode` fails to deserialise and the
      appearance is SILENTLY not pinned). Capturing the "after" pass under the old theme names
      would produce a before/after pair that differs in nothing. The script warns; do not rely on
      the warning.
    - Validation: a before/after pair exists per surface, in both light and dark, under
      `docs/visual/shots/`.
    - Requirements: R5.1

  - [ ] 7.2 - Run the four gate rows
    - ToDo: **Contrast** *(widened at v2 — the v1 row checked only the accent, which is how a
      1.00:1 hairline shipped)* — the accent clears ≥4.5:1 on the editor background in both
      variants (R3.5); the focus ring clears ≥3:1 (R3.9); **`border` ≥1.5:1 and
      `border.variant` ≥1.25:1 against every surface rung** (R3.10). All three are asserted
      by the 5.1 and 5.4 tests; re-check on the shipped shots with `magick`.
      **Token coverage** — regression grep returns zero radius literals in `styled_ext.rs`,
      `button_like.rs` and `toggle.rs`, using the **per-corner-aware** pattern
      `\.rounded_((tl|tr|br|bl)_)?(xs|sm|md|lg|xl|2xl|3xl|full)\(\)`. The v1 pattern is blind
      to `.rounded_tl_md()` and returns 0 against a file still full of literals — do not use it.
      **Fixture** — the pairs come from an identical fixture. **Parity** — no affordance
      lost; 002 is presentational only (R5.3).
      Record each row in **`docs/visual/smoke-002.md`** *(v3: moved out of the gitignored
      `.epic/`, so the evidence is genuinely versioned rather than committed into a void)*, per
      001's precedent: a manual gate is legitimate **because** it is a written, per-item
      checklist committed as evidence. Any red item reopens the owning task.
    - Validation: all four rows green in `docs/visual/smoke-002.md`; `RELEASE_CHANNEL=zeo cargo
      build --release --frozen` passes; `./script/clippy` clean on touched crates (R5.4).
    - Requirements: R5.2, R5.3, R5.4, R3.5, R3.9, R3.10

  - [ ] 7.3 - Update the token gallery with real screenshots
    - Objective: close the loop — the artefact that arbitrated the gate now shows the result.
    - ToDo: republish the gallery Artifact (same URL) with the before/after pairs embedded,
      replacing the CSS mock-ups of the elevation demo with actual captures.
    - Validation: the gallery renders the real shots; the URL is unchanged.
    - Requirements: R5.1

  - [ ] 7.4 - Commit
    - Validation: workspace tree clean; `docs/visual/` is tracked by git (`git check-ignore`
      returns nothing for it) — *the v1 defect this row is fixing: under `.epic/` this commit
      was a silent no-op, and the evidence it claimed to version was never in the repo at all.*
    - Commit: workspace — "feat: visual acceptance evidence for story 002"

## Quality Gates

- [ ] All acceptance criteria validated (R1-R5 via task Validations + `smoke-002.md`)
- [ ] All task validations pass
- [ ] All tests written and passing (Unit: radius scale across `ui_font_size` values,
      elevation invariants. Integration: `shot.sh` contract, theme parse, **the two
      research-defect assertions** — `text.accent != info` and
      `elevated_surface.background != surface.background` — and, **new at v2, the border
      floors** (R3.9/R3.10, sub-task 5.4): 16 token×rung×variant pairs, the assertion whose
      absence let a 1.00:1 hairline through the v1 gate)
- [ ] Code integrated (no orphaned implementations — every token shipped has a consumer
      among the two pilots; this is the specific failure mode this story was scoped to avoid)
      **WAIVED, explicitly, for `ZeoRadius::Xs` (2px) and `::Xxl` (16px)** — they have no
      production consumer in 002. R1.4 *mandates* the full 8-step lattice and D5's nested
      closure needs the intermediate rungs to be computable, so shipping a partial scale would
      break the requirement; story 003 (chrome) consumes both. Recorded as a knowing waiver
      rather than left to look like an oversight — which is what this gate exists to catch.
- [ ] Error handling implemented (no `unwrap()`/`expect()` in new Rust; clippy clean under
      `-D warnings`; `shot.sh` fails loudly rather than emitting zero-byte PNGs)

## Deferred

- Chrome conversion — title bar, tab bar, status bar, docks, pane → **story 003**. Note
  these have **no radius at all** today: 003 *adds* geometry, it does not re-point calls.
- Motion tokens (durations, easings) — values recorded in design.md §Motion for 003 to
  inherit; shipping them here would be orphan code.
- User-facing settings UI for the tokens → **story 006**. The settings hook is built in
  Task 2.1; the editing surface is not.
- Icon theme (`"icon_theme": "Zed (Default)"`) → **story 003** ("consistent icons").
- Font replacement — rejected on evidence, not deferred: GPUI exposes no variable-font axis
  API, and the bundle ships only weights 400 and 600.
