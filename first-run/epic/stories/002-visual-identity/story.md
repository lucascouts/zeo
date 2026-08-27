---
story: zeo-visual-identity
type: feature
scale: full
version: 2
created: 2026-07-11
last-refined: 2026-07-13
history:
  - v1: Initial story
  - v2: Post-validation refinement. R3.5's second clause ("UI boundaries SHALL clear 3:1")
        over-reached WCAG 1.4.11 and was never asserted by any test — split into R3.9 (focus
        ring, which is what 3:1 actually governs, and which already passes) and R3.10 (border
        visibility floors, which fail today). R2.1 gains the perceptibility threshold it
        lacked. R2.7 defers to design.md's radius role table. The rebase Success Metric is
        restated against the real patch set.
---

# Story - Zeo Visual Identity

## Introduction

Zeo's first "wow": opening the editor and seeing an elegant, sophisticated product rather
than a rebranded Zed. Research reframed the work — Zed's geometry is **not** scattered as
assumed; spacing, elevation, typography and colour are already centralised. What is broken
is narrower and more specific: the accent colour is literally Zed's `info` colour, the
"elevated" surface has no background step, and corner radius has no token at all. This
story fixes those three defects, ships the Zeo theme and the final brand art, and lays the
settings-resolved token layer that stories 003 and 006 consume. Requirements are derived
from the approved [design.md](design.md) (decisions D1-D20).

## Requirements

### R1. Design token layer

#### Acceptance Criteria

1. **R1.1** — WHEN a Zeo design token is resolved THE SYSTEM SHALL derive its value from
   the active settings through the application context, and SHALL NOT resolve it from a
   compile-time constant (D1).
2. **R1.2** — WHERE a converted surface renders a corner radius THE SYSTEM SHALL obtain
   that radius from the Zeo radius token, and SHALL NOT use a literal `.rounded_*()` call
   (D3, verified by regression grep over the converted files).
3. **R1.3** — WHEN the radius token resolves to pixels THE SYSTEM SHALL scale with
   `ui_font_size`, matching `DynamicSpacing`'s formula (`ui_font_size × ratio`), and SHALL
   NOT assume a fixed 16px rem base.
4. **R1.4** — WHEN the radius scale is inspected THE SYSTEM SHALL expose the steps
   0 / 2 / 4 / 6 / 8 / 12 / 16 / full, and for every nested pair listed in design.md
   §Radius the value `outer − padding` SHALL land on that scale (D4, D5).
5. **R1.5** — WHEN a user changes a Zeo token setting THE SYSTEM SHALL apply the new value
   to open windows without a restart (D1, via the existing `SettingsStore` observer).
6. **R1.6** — IF a Zeo token is read before the settings provider is registered THEN THE
   SYSTEM SHALL fail loudly at that point rather than render a silently wrong value.
7. **R1.7** — WHEN `zeo.radius_scale` is set THE SYSTEM SHALL multiply every radius step by
   it, and IF the value falls outside 0.5–2.0 THEN THE SYSTEM SHALL clamp it to that range
   (D23).
8. **R1.8** — WHEN the radius scale is resolved THE SYSTEM SHALL return the same value at
   every UI density (radius is density-invariant, D21), and `Full` SHALL be exempt from
   `ui_font_size` scaling (D22).

### R2. Elevation and depth

#### Acceptance Criteria

1. **R2.1** — WHEN an elevated surface is rendered THE SYSTEM SHALL separate it from the
   surface beneath by both a background luminance step and a hairline border, and SHALL
   NOT rely on a drop shadow as the sole depth cue (D7). The hairline SHALL be perceptible
   against the surface it rings — the threshold is R3.10. *(v2: without a threshold, R2.1
   was satisfiable by a border at 1.00:1, which is what shipped.)*
2. **R2.2** — WHEN `elevated()` or `elevated_borderless()` renders a surface THE SYSTEM
   SHALL resolve its background from the supplied `ElevationIndex`, so that `elevation_1`,
   `elevation_2` and `elevation_3` paint **distinct** backgrounds (D24 — today all three
   paint the same colour and `ElevationIndex::bg()` is dead code, which is why fixing the
   palette alone would change nothing).
3. **R2.3** — WHERE a theme does not define `modal_surface_background` THE SYSTEM SHALL
   fall back to `elevated_surface_background`, leaving every existing Zed theme rendering
   exactly as it does today (D25).
4. **R2.4** — WHEN a surface at level `e2` or `e3` is rendered THE SYSTEM SHALL apply an
   inset rim highlight along its top edge (D7).
5. **R2.5** — WHEN any Zeo surface renders a shadow THE SYSTEM SHALL keep peak shadow
   alpha at or below 12%, and SHALL NOT use GPUI's built-in `shadow_sm`/`md`/`lg`/`xl`
   helpers (a Tailwind port at 10-25% alpha — the dated baseline being left behind).
6. **R2.6** — WHEN the `elevated()` and `elevated_borderless()` helpers are converted THE
   SYSTEM SHALL re-skin every dependent surface (pickers, command palette, popovers,
   modals, context menus, toasts) with **no call site modified** (D8).
7. **R2.7** — WHEN a button, checkbox or switch is rendered THE SYSTEM SHALL obtain its
   radius from the Zeo token at the step design.md §Radius assigns to that control's role —
   button → `md` (6px); checkbox → `sm` (4px); switch → `full` (pill) — and SHALL NOT use a
   literal. *(v2: the original text mandated `md` for every control and cited D9 as its
   authority. D9 says only which files the pilot converts; it says nothing about a step. A
   6px switch track is visually broken — the knob is a circle — and a single step for every
   control contradicts design.md principle 5, "a family per role, never one value
   everywhere". The role table is the arbiter.)*

### R3. Zeo theme and palette

#### Acceptance Criteria

1. **R3.1** — WHEN Zeo starts with no user theme override THE SYSTEM SHALL select
   "Zeo Dark" or "Zeo Light" according to the system appearance (D10, D11).
2. **R3.2** — WHEN the Zeo theme family is delivered THE SYSTEM SHALL register both
   variants from `assets/themes/zeo/zeo.json` with **no code change** to the theme
   registry or the asset embedder (D10).
3. **R3.3** — WHEN the Zeo palette is inspected THE SYSTEM SHALL define `text.accent` as
   `#BD93F9` (dark) and `#7C3AED` (light), and this value SHALL differ from `info` in both
   variants (D13 — today they are byte-identical).
4. **R3.4** — WHEN the Zeo palette is inspected THE SYSTEM SHALL define
   `elevated_surface.background` as distinct from `surface.background` in both variants
   (D7 — today they are byte-identical).
5. **R3.5** — WHEN the accent is measured against the editor background THE SYSTEM SHALL
   clear WCAG AA (≥4.5:1) in both variants (D20). *(v2: the original second clause, "and UI
   boundaries SHALL clear 3:1", is split out into R3.9 and R3.10 — see the note under
   R3.10.)*
6. **R3.6** — IF the theme name in `assets/settings/default.json` does not exactly match
   the `name` field inside `zeo.json` THEN a test SHALL fail, rather than the application
   silently falling back to One Dark.
7. **R3.7** — WHILE the Zeo theme is the default THE SYSTEM SHALL keep every Zed theme
   selectable — nothing is removed (the "expand, don't replace" principle).
8. **R3.8** — WHEN the syntax palette is authored THE SYSTEM SHALL derive it from One Dark
   harmonised with the Zeo accent, and SHALL NOT author a syntax palette from scratch
   (D14).
9. **R3.9** — WHEN the focus ring (`border.focused`) is measured against any surface it can
   be painted on THE SYSTEM SHALL clear 3:1, per WCAG 1.4.11 (non-text contrast), in both
   variants.
10. **R3.10** — WHEN a border token is measured against **every** surface rung it can be
    painted on — `background`, `surface`, `elevated_surface`, `modal_surface` — THE SYSTEM
    SHALL clear a visibility floor of **≥1.5:1 for `border`** and **≥1.25:1 for
    `border.variant`**, in both variants. The two floors differ deliberately: a single floor
    collapses the two tokens onto the same colour and destroys the prominence hierarchy that
    162 and 127 call sites consume.

> **Note on R3.5's original second clause (v2).** It read "UI boundaries SHALL clear 3:1"
> and was **never asserted by any test** — `tasks.md` silently narrowed it to "the accent
> clears AA" at both 5.1 and the 7.2 gate row, even though design.md's Testing Strategy and
> D20 gate table both demanded it and noted it was "computable directly from the theme
> JSON". The clause was also **wrong as written**: WCAG 1.4.11 requires 3:1 of *UI
> components* and *focus indicators*, not of decorative separators between surfaces — and a
> literal 3:1 border contradicts design.md's own principles 1 and 10 ("a 1px **low-contrast**
> border"; "borders are **translucent, often sub-pixel**"). R3.9 keeps the part WCAG
> actually mandates (and it already passes: 3.77–5.81:1). R3.10 replaces the rest with a
> *perceptibility* floor, which is the property R2.1 actually needs — and which today's
> palette fails at **1.00:1**.

### R4. Brand art

#### Acceptance Criteria

1. **R4.1** — WHEN the final art is delivered THE SYSTEM SHALL replace story 001's
   placeholder **in place** — same filenames, same sizes: `app-icon-zeo.png` (512),
   `app-icon-zeo@2x.png` (1024), and `hicolor/{512x512,1024x1024}/apps/dev.zeo.Zeo.png`
   (D19).
2. **R4.2** — WHEN the art is authored THE SYSTEM SHALL commit its SVG source with
   authorship stated, and the art SHALL NOT derive from the Power Rangers franchise (a
   Hasbro property) nor from Zed's trademarked mark (D18 — symmetric to story 001's rule).
3. **R4.3** — WHEN the art is validated THE SYSTEM SHALL show the new icon in the running
   window, verified by the checksum of the *installed* file having changed **and** visual
   confirmation after a build with `RELEASE_CHANNEL=zeo` and a KDE icon-cache rebuild —
   never by "the PNG was replaced" alone.
4. **R4.4** — WHEN the art's palette is chosen THE SYSTEM SHALL derive it from the Zeo
   accent, and SHALL NOT retain the placeholder's indigo→teal family (D19).

### R5. Acceptance and validation

#### Acceptance Criteria

1. **R5.1** — WHEN the screenshot harness runs THE SYSTEM SHALL capture from a fixed
   fixture — same file open, same panels, same window size — in both light and dark, so
   that before/after pairs are comparable (D20).
2. **R5.2** — IF `slurp` is unavailable THEN THE SYSTEM SHALL still produce comparable
   crops, by capturing the full output and cropping against fixed coordinates.
3. **R5.3** — WHEN story 002 is complete THE SYSTEM SHALL have changed presentation only:
   every Zed shortcut, layout and flow SHALL survive untouched (parity).
4. **R5.4** — WHEN the build gate runs THE SYSTEM SHALL pass
   `RELEASE_CHANNEL=zeo cargo build --release --frozen` and `cargo clippy` clean under
   `-D warnings` on the touched crates.

## Success Metrics

- Before/after screenshot pairs for both pilots and the theme, in light and dark, reviewed
  and accepted at the gate — the "wow" is observed, not asserted.
- The two research defects are enforced by tests (`text.accent != info`,
  `elevated_surface.background != surface.background`) so they cannot silently return.
- Rebase cost stays bounded: **17 upstream files modified + 9 added** (measured at v2, over
  the story's fork commits). Of the 17, **8 carry substantive edits**
  (`theme_settings_provider.rs`, `theme_settings.rs`, `colors.rs`, `settings_content/theme.rs`,
  `elevation.rs`, `styled_ext.rs`, `button_like.rs`, `toggle.rs`); the rest are mechanical
  and unavoidable — `mod`/`pub use` registrations, two `Cargo.toml` dev-dependency lines, and
  the exhaustive-struct-init sites that adding a field to `ThemeColors` and a group to
  `SettingsContent` forces (`default_colors.rs`, `fallback_themes.rs`, `schema.rs`,
  `settings_content.rs`, `vscode_import.rs`) — plus the 2-line `default.json` hunk in a block
  whose 6-month line churn is 0.
  *(v1 claimed "at most 6 upstream files". That target predates the round-2 amendments: D23
  (the `zeo` settings group) and D25 (`modal_surface_background`) were approved after it and
  each forces its own fan-out of exhaustive-init sites. The metric was stale, not breached by
  drift — no call site of `elevated()` was touched, which is the rebase risk that actually
  mattered, and R2.6 holds.)*
- Story 006's knob list maps 1:1 onto tokens shipped here, with no token renamed.

## Constraints

- Tokens are settings-resolved, never compile-time constants (D1).
- The GPUI radius constants (`gpui_macros/src/styles.rs`) are **not** the substrate (D2) —
  they are compile-time and would kill story 006's 1:1 knob→token mapping. Documented
  fallback only.
- Theme JSON carries **colour only**; geometry lives in the token module — `ThemeStyleContent`
  has no geometry field, and adding one would mean patching four hot upstream files.
- No typography token at weight 500: the bundle ships only Regular (400) and SemiBold
  (600), so a 500 token would be unbacked and silently synthesised (D15).
- No token for tracking, blur, >2-stop gradients, container transforms, or per-side border
  colours — GPUI physically cannot render them (D17).
- Chrome containers (title bar, tab bar, dock, pane) are untouched — the repo's hottest
  churn, and they have no radius to re-point (→ story 003).
- No new Rust dependency; build `--frozen` against upstream's `Cargo.lock`.
- `scripts/shot.sh`: `set -euo pipefail`, quoted expansions, shellcheck-clean (global
  shell rules).
- Rust rules: no `unwrap()`/`expect()` in new production code; `cargo clippy` clean on
  touched crates.
- Trademark: the art may be evocative, never derivative — applied symmetrically to Hasbro
  (Power Rangers) and to Zed (D18).
- E2E tooling: none applicable (native GPUI desktop app) — scripted screenshots + manual
  smoke, per story 001's precedent.

## Out of Scope

- Chrome component conversion — title bar, tab bar, status bar, docks, pane (story 003).
  Note these currently have **no radius at all**: 003 will be *adding* geometry, not
  re-pointing existing calls.
- Motion tokens (durations, easings) — recorded in design.md for story 003 to inherit;
  shipping them here would leave orphan code with no consumer (D16).
- Icon theme (`"icon_theme": "Zed (Default)"`) — story 003 ("consistent icons").
- The user-facing settings UI for the tokens — story 006. The settings *hook* is built
  here; the editing surface is not.
- Font replacement (Inter Variable and similar) — rejected on evidence: GPUI exposes no
  variable-font axis API, so off-grid weights cannot be relied on (D15).
- `DEFAULT_LIGHT_THEME` / `DEFAULT_DARK_THEME` constants and the `zed_default_themes()`
  fallback family — left as Zed's; they apply only when the registry is empty.
- Packaging, the `app-editors/zeo` ebuild, distribution (story 007).
