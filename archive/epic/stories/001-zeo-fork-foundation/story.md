---
story: zeo-fork-foundation
type: feature
scale: full
version: 1
created: 2026-07-10
---

# Story - Zeo Fork Foundation

## Introduction

Zeo is a standalone, installable fork of the Zed editor focused on visual/UX enhancement,
openly identified as a Zed fork. This story delivers the foundation every later story
builds on: a real git fork tracking upstream daily snapshots, minimal functional
rebranding (Zeo identity, safe coexistence with an installed Zed), the 7 existing overlay
patches incorporated as commits, a working release build, and a scripted, failure-safe
upstream-sync workflow. Requirements are derived from the approved
[design.md](design.md) (decisions D1-D10).

## Requirements

### R1. Workspace foundation

#### Acceptance Criteria

1. **R1.1** — WHEN the workspace repository (`zeo/`) is initialized THE SYSTEM SHALL
   exclude `.epic/` and `fork/` from version control (verified via `git check-ignore`).
2. **R1.2** — WHEN the foundation is delivered THE SYSTEM SHALL provide `docs/SYNC.md`,
   `docs/BUILD.md`, `docs/REBRAND.md`, and `docs/UPSTREAM.md` documenting the sync
   procedure, the local build procedure, every rebrand touch-point with its rationale,
   and the fork base snapshot/remote topology.

### R2. Fork creation and patch incorporation

#### Acceptance Criteria

1. **R2.1** — WHEN the fork clone is set up THE SYSTEM SHALL have remote `origin`
   pointing to the user-owned Zeo repository and remote `upstream` pointing to
   `zed-industries/zed` with its push URL disabled (verified via `git remote -v`).
2. **R2.2** — WHEN the 7 overlay patches (0001, 0002, 0005-0009) are applied onto the
   pinned snapshot commit THE SYSTEM SHALL produce one commit per patch, in series
   order, preserving original authorship and commit messages (verified via `git log`).
3. **R2.3** — IF a patch fails to apply THEN THE SYSTEM SHALL abort the import leaving
   the branch with no partially-applied patch state.
4. **R2.4** — WHEN the branch `zeo` is rebased from the pinned snapshot onto the current
   `upstream/main` THE SYSTEM SHALL retain all patch and rebrand commits with the
   working tree building successfully afterwards.

### R3. Zeo identity and coexistence

#### Acceptance Criteria

1. **R3.1** — WHEN the built application reports its identity THE SYSTEM SHALL display
   the name "Zeo" and release channel `zeo` (window title/about and version output).
2. **R3.2** — WHEN the application starts under Wayland THE SYSTEM SHALL register the
   app_id `dev.zeo.Zeo`, and the installed icon file name SHALL match that app_id.
3. **R3.3** — WHEN the application reads or writes user state THE SYSTEM SHALL use
   `~/.config/zeo` and `~/.local/share/zeo` exclusively.
4. **R3.4** — WHILE Zeo runs on a host with the overlay Zed installed THE SYSTEM SHALL
   NOT read or modify `~/.config/zed` or any Zed state directory, and both applications
   SHALL run simultaneously without interference.
5. **R3.5** — WHEN the auto-update path is evaluated THE SYSTEM SHALL perform no
   download and no binary replacement, reporting that updates are managed externally.
6. **R3.6** — IF a remote-server binary auto-download is requested for the `zeo` channel
   THEN THE SYSTEM SHALL fail with a message referencing the `ZED_COPY_REMOTE_SERVER`
   override instead of fetching any artifact from zed.dev.
   > _Corrected during validation (2026-07-11, deviation **D-001**). This requirement
   > originally named `ZED_REMOTE_SERVER_PATH`, which **does not exist** in snapshot
   > `5f8a7413` (zero occurrences fork-wide). The real prebuilt-binary override is
   > `ZED_COPY_REMOTE_SERVER` (`crates/remote/src/transport.rs:252`). The implementation
   > was right and the requirement text was wrong; the intent — no zed.dev fetch, a real
   > documented override cited — is unchanged._
7. **R3.7** — WHEN the build output is inspected THE SYSTEM SHALL name the application
   binary `zeo` and expose the CLI entry point as `zeo`, with no file colliding with the
   installed Zed's executables.
8. **R3.8** — WHEN the desktop entry is installed THE SYSTEM SHALL declare `Name=Zeo`
   and an icon reference resolving to the new placeholder assets (512 px and 1024 px),
   which SHALL NOT be derived from Zed's trademarked artwork.

### R4. Release build

#### Acceptance Criteria

1. **R4.1** — WHEN `cargo build --release --frozen` is executed for the application and
   CLI packages on the Gentoo host THE SYSTEM SHALL complete without errors.
2. **R4.2** — WHEN upstream unit tests are run for the crates touched by the rebrand
   (`release_channel`, `paths`, auto-update) THE SYSTEM SHALL pass them.
3. **R4.3** — WHEN the built application opens the agent panel THE SYSTEM SHALL exhibit
   the patched behaviors as smoke evidence: the manual-mode badge (patch 0007) and
   clickable attachments (patch 0008).

### R5. Upstream-sync workflow

#### Acceptance Criteria

1. **R5.1** — WHEN the sync script runs and the rebase applies cleanly and the build
   gate passes THE SYSTEM SHALL leave branch `zeo` on the new upstream tip and record it
   as the last-good SHA.
2. **R5.2** — IF the rebase hits a conflict THEN THE SYSTEM SHALL abort the rebase,
   leave the branch at the last-good SHA, and exit non-zero with a message naming the
   conflicting step.
3. **R5.3** — IF the post-rebase build gate fails THEN THE SYSTEM SHALL restore the
   branch to its pre-sync state and exit non-zero.
4. **R5.4** — WHEN the sync script completes in any outcome THE SYSTEM SHALL leave no
   temporary tags or rebase state behind except the recorded last-good marker.

## Success Metrics

- One full sync cycle executed end-to-end: pinned snapshot → newer `upstream/main`, all
  12 commits (7 patches + 5 rebrand) surviving with a green build.
- Zeo and overlay Zed installed and launched side-by-side with zero shared state.
- Time-to-resolve a daily sync (no conflicts) under 10 minutes including build gate.

## Constraints

- Shallow rebrand only: no internal crate/package renames (D1).
- Base tracks `upstream/main` (daily-snapshot cadence), starting from the exact commit
  pinned by `zed-1.12.0_pre20260710-r1.ebuild` (D6, design §2).
- No new Rust dependencies; build `--frozen` against upstream `Cargo.lock`.
- Sync script: `set -euo pipefail`, quoted expansions, shellcheck-clean (global shell rules).
- Never push to `upstream` (D7).
- E2E tooling: none applicable (native GPUI desktop app) — manual smoke + scripted checks.
- Rust rules: no `unwrap()`/`expect()` in new production code; `cargo clippy` on touched crates.

## Out of Scope

- Visual identity/theme and design tokens (story 002); modern chrome (story 003).
- Visual Extension API (stories 004-005, per ZEO.md §5).
- User-facing UI customization settings (story 006).
- Gentoo ebuild `app-editors/zeo`, packaging, distribution, binary releases (story 007).
- Automatic settings migration from `~/.config/zed` (manual copy documented instead).
- macOS/Windows support validation (Linux/Gentoo host only in this story).
- Final logo/icon artwork (placeholder only; final art arrives with story 002).
- Any self-update infrastructure for Zeo.
