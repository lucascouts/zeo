---
story: zeo-fork-foundation
type: feature
scale: full
version: 1
created: 2026-07-10
---

# Implementation Plan - Zeo Fork Foundation

## Overview

Sequencing: workspace repo → fork clone/topology → patch import at the pinned snapshot →
rebrand commit set → release build + identity validation → sync workflow and the first
real sync to `upstream/main`. The Integration test for the sync script is **pre-authored
and Red-verified** at `.draft/authored-tests/tests/sync-upstream.test.sh`; the executor
of Task 6.1 materializes it to `tests/sync-upstream.test.sh` and implements until Green.
Fork-side work happens in `fork/` (its own git repo); workspace-side work (docs, scripts,
tests) happens in this repo.

## Task List

- [x] 1 - Workspace repository setup
  - _Complexity: Trivial | Tests: None | Risks: None | Dependencies: None_
  - Objective: workspace repo exists with correct exclusions and skeleton.

  - [x] 1.1 - Initialize workspace repo and skeleton
    - Objective: version the project home without ever tracking `.epic/` or `fork/`.
    - ToDo: `git init`; extend the existing `.gitignore` (already has `.epic`) with
      `fork/`; create `docs/`, `scripts/`, `tests/` (`.gitkeep`); initial commit.
    - Validation: `git check-ignore .epic fork` succeeds; `git log --oneline -1` shows
      the initial commit.
    - Requirements: R1.1
    - Commit: "chore: initialize zeo workspace"

- [x] 2 - Fork clone and git topology
  - _Complexity: Simple | Tests: None | Risks: multi-GB clone, network-dependent | Dependencies: Task 1_
  - Objective: `fork/` clone with safe remotes and branch `zeo` at the ebuild-pinned SHA.

  - [x] 2.1 - Clone and configure remotes
    - Context:
      - Files: `/home/otaku/Projetos/git/bentoo/app-editors/zed/zed-1.12.0_pre20260710-r1.ebuild` (SRC_URI/commit, env workarounds), `ZEO.md` §7 (workspace rules)
    - Objective: full-history clone, `origin` user-owned, `upstream` fetch-only.
    - ToDo: create the user-owned empty repo (e.g. `gh repo create <user>/zeo`; if `gh`
      is unauthenticated, pause and ask the user for the remote URL — do not skip the
      push target, D7 requires it); `git clone --filter=blob:none
      https://github.com/zed-industries/zed fork` (never `--depth 1` — rebase needs
      history); rename remote to `upstream`, add `origin` = user repo;
      `git remote set-url --push upstream DISABLED`; `git config rerere.enabled true`.
      On clone failure (network), abort with a clear message and leave no partial dir.
    - Validation: `git remote -v` shows `upstream … DISABLED (push)` and `origin` set;
      `git config rerere.enabled` prints `true`.
    - Requirements: R2.1

  - [x] 2.2 - Branch `zeo` at the pinned snapshot commit
    - Objective: the branch starts exactly where the overlay patches are known to apply.
    - ToDo: extract the pinned commit from the ebuild (SRC_URI/EGIT commit; ZEO.md cites
      snapshot `5f8a7413a31769`, confirm against the ebuild and use the full SHA); if the
      filtered clone lacks it, `git fetch upstream <sha>` and handle a missing-commit
      error by aborting with a message; `git branch zeo <sha> && git switch zeo`; record
      the SHA + remote topology in `docs/UPSTREAM.md`.
    - Validation: `git rev-parse zeo` equals the pinned SHA.
    - Requirements: R2.2
    - Commit: "docs: record fork base snapshot and remote topology" (workspace)

- [x] 3 - Overlay patch import
  - _Complexity: Moderate | Tests: None | Risks: patch/base mismatch; 0002 feature gating | Dependencies: Task 2_
  - Objective: the 7 overlay patches become 7 commits on `zeo`, authorship preserved.

  - [x] 3.1 - Apply the patch series with `git am`
    - Context:
      - Files: `/home/otaku/Projetos/git/bentoo/app-editors/zed/files/*.patch` (the 7 patches), `ZEO.md` §5 (sizes/roles)
    - Objective: one commit per patch, series order, no partial state on failure.
    - ToDo: from `fork/` on `zeo`, apply with an explicit array in order 0001 → 0002 →
      0005 → 0006 → 0007 → 0008 → 0009 (GOTCHA: 0003/0004 do not exist — the gap is
      intentional, never glob blindly); on `git am` failure run `git am --abort` and exit
      non-zero naming the failing patch (R2.3); confirm authorship/messages preserved.
    - Validation: `git log --oneline -7` matches the 7 patch titles; `git status` clean.
    - Requirements: R2.2, R2.3
    - Commit: the 7 imported commits themselves (no extra commit)

  - [x] 3.2 - Verify 0001/0002 self-sufficiency without USE gating
    - Objective: the agent integration compiles enabled-by-default (ebuild gate gone).
    - ToDo: GOTCHA from design §3 — 0002 is USE-conditional in the ebuild; grep the
      feature/cfg that 0001 ("force-enable") flips and confirm it is on by default;
      `cargo check` (default features) on the affected crates and handle failure by
      adding a fork commit adjusting default features, documented later in REBRAND.md.
    - Validation: `cargo check` passes with default features; grep shows the agent
      feature enabled by default.
    - Requirements: R2.2

- [x] 4 - Rebrand commit set
  - _Complexity: High | Tests: None (upstream suites run in Task 5) | Risks: hidden hardcoded `dev.zed.Zed*`/`zed.dev` sites | Dependencies: Task 3_
  - Objective: minimal functional Zeo identity as a contiguous block of 5 commits (D1-D4, D9, D10).

  - [x] 4.1 - `ReleaseChannel::Zeo` variant + channel file
    - Context:
      - Files: `fork/crates/release_channel/src/` (enum + match sites), `fork/crates/zed/RELEASE_CHANNEL` (verify actual mechanism — the ebuild writes it at build time)
    - Objective: channel-keyed identity resolved exhaustively at compile time.
    - ToDo: add the `Zeo` variant; set channel file/default to `zeo`; let the compiler
      surface every match site and resolve each consciously — display name "Zeo", app_id
      `dev.zeo.Zeo`, URL scheme `zeo://`; any `zed.dev` URL arm gets an explicit
      keep/change decision recorded for REBRAND.md (4.5). No `unwrap()`/`expect()` in
      new code — propagate with `?`/`Result`. Fork commit.
    - Validation: `cargo check -p release_channel && cargo test -p release_channel` pass.
    - Requirements: R3.1, R3.2

  - [x] 4.2 - Neutralize auto-update and remote_server download
    - Objective: no self-replacement path; no zed.dev artifact fetch for `zeo`.
    - ToDo: in the auto-update crate, the `Zeo` arm reports "updates managed externally"
      (same UX as `ZED_UPDATE_EXPLANATION`) and never reaches a download call; the
      remote_server auto-download path for `Zeo` returns an error citing
      `ZED_REMOTE_SERVER_PATH` (R3.6) — errors propagated with `?`, no panics. Fork commit.
    - Validation: `cargo check -p auto_update` (+ its tests if present); grep confirms no
      zed.dev fetch reachable from the `Zeo` arm.
    - Requirements: R3.5, R3.6

  - [x] 4.3 - State paths `~/.config/zeo` / `~/.local/share/zeo`
    - Objective: full state separation from Zed (coexistence).
    - ToDo: patch `fork/crates/paths` so config/data/cache resolve under `zeo`; verify no
      code path falls back to reading `~/.config/zed` (R3.4). Fork commit.
    - Validation: `cargo test -p paths` passes; `grep -rn "config/zed"` over the paths
      crate shows no Zeo-reachable fallback.
    - Requirements: R3.3, R3.4

  - [x] 4.4 - Binary names `zeo` (app + CLI)
    - Objective: no PATH collision with the installed Zed.
    - ToDo: verify the current bin layout first (upstream: app binary `zed` in
      `crates/zed`, CLI in `crates/cli` installed as the `zed` command); replicate the
      same relationship under `zeo` via `[[bin]]` names; fix internal references that
      spawn or locate the binaries by name (cli↔app discovery) and handle lookup failure
      paths. Fork commit.
    - Validation: `cargo build -p zed -p cli` (debug) produces artifacts named `zeo`
      (app) and the CLI entry exposed as `zeo`.
    - Requirements: R3.7

  - [x] 4.5 - Desktop entry, placeholder icons, REBRAND.md inventory
    - Objective: installable identity assets, legally clean.
    - ToDo: create new placeholder icons (512 + 1024 px, original art — never derived
      from Zed's trademarked mark) following the `app-icon-*.png` resource layout;
      `.desktop` with `Name=Zeo`, `Icon=dev.zeo.Zeo`, `StartupWMClass`/app_id matching —
      GOTCHA: the icon file name MUST equal the app_id for Wayland icon resolution (the
      current ebuild warns exactly about this); write `docs/REBRAND.md`: full inventory
      of touch-points + `grep -rn "dev.zed.Zed\|zed\.dev"` results (telemetry, crash
      reporter, URL scheme) each with a keep/change rationale (R1.2). Fork commit for
      assets, workspace commit for the doc.
    - Validation: `desktop-file-validate` passes; icon file names match `dev.zeo.Zeo`;
      REBRAND.md lists every grep hit with a decision.
    - Requirements: R3.8, R3.2, R1.2

  - [x] 4.6 - Commit
    - Validation: `cargo check` (workspace) passes; `git log` shows the 5 rebrand
      commits as a contiguous block on top of the 7 patch commits.
    - _Reconciled at validation: the stack carries **14** commits, not the planned 12.
      The 5 rebrand commits ARE contiguous on top of the 7 patch commits as specified;
      two follow-ups sit above them — `afcf2eb103` (clippy-clean of the patch-0002 crate,
      required for Gate 4) and `f7218425ad` (startup-log rebrand). Both registered in
      `.draft/deviations.yaml`._
    - Commit: rebrand lands as the 5 per-concern fork commits above (4.1-4.5); workspace
      commit "docs: rebrand touch-point inventory"

- [x] 5 - Release build and identity validation
  - _Complexity: Moderate | Tests: None (this task executes the suites) | Risks: long build; ebuild env workarounds | Dependencies: Task 4_
  - Objective: green release build and observable Zeo identity (D8).

  - [x] 5.1 - Release build + BUILD.md
    - Context:
      - Files: overlay ebuild (RUSTFLAGS/env/cargo config the build needs outside portage)
    - Objective: reproducible local release build.
    - ToDo: `cargo build --release --frozen` for the app + CLI packages (exact package
      list confirmed in 4.4); replicate required ebuild env workarounds; document the
      full procedure in `docs/BUILD.md` (R1.2); on failure, capture the error, fix
      forward or report as blocked.
    - Validation: build exits 0; `target/release/zeo` exists.
    - Requirements: R4.1, R1.2
    - Commit: "docs: local release build procedure" (workspace)

  - [x] 5.2 - Upstream tests + clippy on touched crates
    - Objective: no regression in the crates the rebrand touched.
    - ToDo: `cargo test -p release_channel -p paths -p auto_update` (adjust names to the
      real crates touched); `cargo clippy` on the same crates — no new warnings on new
      code (Rust rules); `cargo audit` skipped with rationale: no dependency changes.
    - Validation: all suites pass; clippy clean on touched code.
    - Requirements: R4.2

  - [x] 5.3 - Wayland smoke checklist (manual)
    - Objective: observable identity, coexistence, and patched agent behaviors.
    - ToDo: launch `target/release/zeo` under Wayland and verify each item, recording
      results in `.epic/stories/001-zeo-fork-foundation/smoke-001.md`: (1) window/about
      shows "Zeo" + channel `zeo`; (2) compositor reports app_id `dev.zeo.Zeo` and the
      icon resolves; (3) `~/.config/zeo` + `~/.local/share/zeo` created; (4) checksum of
      `~/.config/zed` unchanged after the session while overlay Zed runs simultaneously;
      (5) binaries named `zeo`, no PATH collision; (6) agent panel shows the 0007
      manual-mode badge and 0008 clickable attachments; (7) a manual update check
      surfaces the "updates managed externally" message and performs no download (R3.5);
      (8) `xdg-mime query default x-scheme-handler/zeo` resolves to the Zeo desktop
      entry. Interface check (design §4↔§6): desktop `Icon=` == app_id == icon file
      name. Failure handling: any red item reopens the owning task (4.x) and is fixed
      before this sub-task completes — a changed `~/.config/zed` checksum is an R3.4
      violation, never ignorable.
    - Validation: all 8 checklist items green in `smoke-001.md`.
    - Requirements: R3.1, R3.2, R3.3, R3.4, R3.5, R3.7, R4.3

- [x] 6 - Upstream sync workflow
  - _Complexity: Moderate | Tests: Integration (pre-authored, Red-verified) | Risks: real sync spans weeks of upstream drift — conflicts expected | Dependencies: Task 5_
  - Objective: failure-safe scripted sync (D6) proven by a real sync to `upstream/main`.

  - [x] 6.1 - `scripts/sync-upstream.sh` + SYNC.md (test-first)
    - Context:
      - Files: `.draft/authored-tests/tests/sync-upstream.test.sh` (READ FIRST — it pins the behavior contract, incl. the last-good marker at `<repo>/.git/zeo-last-good`)
    - Objective: implement the sync script until the authored test is Green.
    - ToDo: materialize the authored test to `tests/sync-upstream.test.sh` and re-confirm
      Red; implement `scripts/sync-upstream.sh` with args `--repo` (default `fork/`),
      `--to` (default `upstream/main`), `--build-cmd` (default fast `cargo check`):
      fetch → tag `zeo-pre-sync` → rebase (rerere on) → build gate → on success write
      `<repo>/.git/zeo-last-good` and drop the tag; on conflict `git rebase --abort`,
      exit non-zero naming the step; on gate failure reset to `zeo-pre-sync`, exit
      non-zero; every outcome cleans tag/rebase state (R5.4). Shell rules:
      `set -euo pipefail`, quoted expansions, arrays for args. Then Green → Refactor.
      Write `docs/SYNC.md`: procedure, pin policy, conflict playbook (R1.2).
    - Tests: Integration · `tests/sync-upstream.test.sh` — clean sync leaves `zeo` on new
      tip with commit surviving + marker updated; conflict → abort, pinned, non-zero;
      gate failure → restored pre-sync state, non-zero; no leftover tags/rebase state
    - Validation: `bash tests/sync-upstream.test.sh` passes; `shellcheck
      scripts/sync-upstream.sh` clean — RESOLVED at validation time: shellcheck IS present
      (`/usr/bin/shellcheck` 0.11.0); first actual run is clean (exit 0, zero findings).
      The earlier "shellcheck absent on this host" note was stale.
    - Requirements: R5.1, R5.2, R5.3, R5.4, R1.2

  - [x] 6.2 - First real sync to `upstream/main`
    - Objective: prove the whole 12-commit stack survives a real rebase (R2.4).
    - ToDo: run the script against `fork/` with the real build gate; resolve conflicts
      manually (rerere records them); if unresolvable, stay pinned and report blocked
      (that IS the designed behavior, not a task failure); verify the 7 patch + 5
      rebrand commits sit on the new tip; ⚠ Fidelity (Test Advisor): this run is the
      only real-build-gate exercise — do not substitute a mock gate here.
    - Tests: Covered by Task 6.1
    - Validation: `git log` shows the stack on the new upstream tip;
      `cargo build --release --frozen` green on the new tip.
    - Requirements: R2.4, R5.1
    - _Validation finding (R2.4): the run was a **no-op rebase**. `upstream/main` is
      genuinely still `5f8a7413a3` — confirmed against the live remote (`git ls-remote`
      + GitHub API): Zed's `main` has not moved since 2026-07-10 23:24Z. So the stack was
      rebased onto a ref identical to its own base and no patch commit was ever replayed
      against moved upstream code. The build gate ran green on an unchanged tree.
      R2.4 is therefore proven **structurally only**; the conflict/abort machinery is
      proven by the fixture test, not by production drift. See Task 7.1 — the script
      could not tell you this, which is the actual defect._

  - [x] 6.3 - Commit
    - Validation: `bash tests/sync-upstream.test.sh` passes; workspace tree clean.
    - Commit: "feat: upstream sync workflow (script, tests, docs)" (workspace) + push
      `zeo` to `origin` (fork)
    - _Push RESOLVED 2026-07-11 (was deferred). `origin` was recreated as a **real GitHub
      fork** of `zed-industries/zed` — a plain repo would have had to upload Zed's entire
      history (GBs), and a blobless clone cannot even do that without re-fetching every
      blob; a fork shares the upstream object network, so the stack pushed in seconds.
      `zeo` is live at `github.com/lucascouts/zeo` (public — a fork of a public repo cannot
      be private). The old empty `lucascouts/zeo` was renamed to `zeo-workspace` and now
      serves as the private workspace remote. See `docs/UPSTREAM.md` for the topology and
      the operational rules (no "Sync fork" button; Actions OFF; force-with-lease after
      fetch)._

- [x] 7 - Post-validation remediation
  - _Complexity: Simple | Tests: Integration (7.1, test-first) | Risks: none | Dependencies: Task 6_
  - Objective: close the two real defects surfaced by `/epic:epic stories validate 001`.

  - [x] 7.1 - Make a no-op sync distinguishable from a real one (test-first)
    - Context:
      - Files: `scripts/sync-upstream.sh` (the `git rebase "$TO"` call), `tests/sync-upstream.test.sh`
    - Objective: the script must never report "rebased … gated green" when it rebased nothing.
    - ToDo: capture `git rev-parse "$TO"` and the branch tip BEFORE the rebase; when `$TO` is
      already an ancestor of `zeo` (nothing to replay), report explicitly — e.g.
      `OK: already up to date at <sha> — nothing to rebase` — and exit 0 WITHOUT claiming a
      rebase happened. A real rebase keeps the existing success message. The marker
      (`<repo>/.git/zeo-last-good`) is still written in both cases (the tip is still good), and
      the build gate still runs (it is what makes the marker meaningful). Preserve the trap/
      no-residue contract (R5.4). Shell rules: `set -euo pipefail`, quoted expansions, arrays.
      Test-first: author the new scenario Red BEFORE touching the script.
    - Tests: Integration · `tests/sync-upstream.test.sh` — new scenario s4: `--to` pointing at a
      ref already merged into `zeo` → exit 0, tip UNCHANGED, stdout says "already up to date"
      and does NOT claim a rebase, marker present, no residue. Existing 19 checks stay green.
    - Validation: `bash tests/sync-upstream.test.sh` passes (19 + new checks);
      `shellcheck scripts/sync-upstream.sh` clean.
    - Requirements: R5.1, R5.4
    - _Done 2026-07-11. Red first (27 checks / 2 failures — the script's own summary line
      read `OK: zeo rebased onto upstream/main and gated green` on a sync that replayed
      nothing), then Green. Script now detects `merge-base --is-ancestor "$TO" zeo` BEFORE
      rebasing and reports `OK: zeo already up to date with … (nothing to rebase)`.
      **A 5th scenario was added beyond the plan**: s5 exercises gate-failure ON the no-op
      path (R5.3). The Executor had left it proven "by code symmetry" only — i.e. exactly
      the untested-error-path trap R2.3 fell into in this same story. It passes.
      Final: `bash tests/sync-upstream.test.sh` → **33 checks, 0 failures**;
      `shellcheck scripts/sync-upstream.sh` → clean, exit 0._

  - [x] 7.2 - Document the patch-import failure path (R2.3 evidence gap)
    - Objective: R2.3 stops resting on prose alone.
    - ToDo: the import is a completed one-shot — there is no script to write and none should be
      invented. Record the truth in `docs/UPSTREAM.md`: the exact `git am` series command used,
      that atomicity on failure is guaranteed by `git am`'s own semantics (`git am --abort`
      restores the pre-import tip, never a partial series), and that the abort path was NEVER
      exercised because all 7 patches applied clean on the first try. State the re-import
      procedure for a future contributor.
    - Validation: `docs/UPSTREAM.md` states the command, the abort semantics, and the
      "never exercised" fact.
    - Requirements: R2.3, R1.2

  - [x] 7.3 - Commit
    - Validation: `bash tests/sync-upstream.test.sh` passes; `shellcheck` clean; tree clean.
    - Commit: "fix: report a no-op sync explicitly; document the patch-import abort path"
    - _Done 2026-07-11 → `24071d5` (workspace). Tree clean. A second, unrelated commit
      `fd2b1d8` versions `docs/ROADMAP.md` + `docs/ZEO.md` in the tracked tree by explicit
      user decision, reversing b5bf793's placement._

## Quality Gates

- [x] All acceptance criteria validated (R1, R2, R3, R4, R5 via task Validations + smoke-001.md)
      — R1.1/R1.2 ✓ (4 docs delivered); R2.1/R2.2 ✓ (7 patch commits, original authorship preserved;
      pinned base is an ancestor of `zeo`); **R2.3 ⚠ no artifact** (the `git am --abort` path exists
      nowhere in the repo — the patches applied clean on the first try, so it was never exercised;
      atomicity rests on `git am`'s own semantics. Task 7.2 documents this instead of faking an
      artifact); **R2.4 ⚠ structurally only** (the "real sync" was a **no-op rebase**: `upstream/main`
      is genuinely still the pinned base — verified against the live remote, Zed's `main` has not
      moved since 2026-07-10 23:24Z. Nothing was replayed against moved upstream code. The conflict
      path is covered by the fixture test; the first real drift will exercise it. Task 7.1 fixes the
      script's inability to tell you this); R3.1-R3.5, R3.8 ✓ (verified in code + smoke-001.md);
      **R3.6 ⚠ env var renamed** (deviation D-001: `ZED_REMOTE_SERVER_PATH` does not exist in this
      snapshot; the real override is `ZED_COPY_REMOTE_SERVER` — intent preserved, no zed.dev fetch);
      **R3.7 ⚠ half-deferred** (app binary IS `zeo` and there is no PATH collision, but the CLI cargo
      bin stays `cli` — deviation D-004, the `zeo` command arrives with story-007 packaging);
      R4.1-R4.3 ✓; R5.1-R5.4 ✓ (19/19 integration checks).
- [x] All task validations pass — re-verified empirically by the Validator on 2026-07-11: every
      sub-task validation returns its expected result. (3.1's checkbox was stale and is now `[x]`;
      6.1's `shellcheck` check was reported as skipped but shellcheck IS installed — first actual
      run is clean.) **Caveat:** `cargo test -p paths` (4.3) is a **vacuous pass** — the `paths`
      crate contains zero `#[test]` functions. What actually carries R3.3/R3.4 is the grep over the
      crate (single `APP_NAME` chokepoint, no Zeo-reachable fallback to `~/.config/zed`) plus the
      before/after sha256 of Zed's config tree in smoke-001.md.
- [x] All tests written and passing (Integration test Green 19/19; upstream suites pass;
      clippy `-D warnings` clean on `release_channel`, `paths`, `auto_update`)
      — **one pre-existing upstream failure**: `auto_update::test_auto_update_downloads`
      ("database not initialized", db.rs:88). Verified by stash to fail identically on unmodified
      upstream code; NOT a regression from this story and deliberately not fixed. No other failure
      of any kind was observed during validation.
- [x] Code integrated (no orphaned implementations) — **weaker than it reads**: the sync script's
      rebase-and-replay path has only ever run against the 3-commit fixtures in the integration
      test. The "real sync" of 6.2 was a no-op (see R2.4 above), so the script has never replayed
      the real 14-commit stack. Not false, but do not read it as production-proven.
- [x] Error handling implemented (sync conflict/gate/no-residue paths — all three proven by the
      fixture test; remote_server bails via `anyhow::bail!` before any network call; compiler-
      enforced channel exhaustiveness, no runtime "unknown channel"; no `unwrap()`/`expect()` in
      new Rust; clippy clean under `-D warnings`) — **minus the `git am` abort path**, which is
      claimed but has no artifact (see R2.3 above).

## Published (2026-07-11)

- **`github.com/lucascouts/zeo`** — public, a real fork of `zed-industries/zed`; default
  branch `zeo`, **15 commits** on the pinned base (7 patches + 5 rebrand + 3 follow-ups:
  clippy-clean, startup log, README). Actions **explicitly disabled** — the fork arrived
  with them ON (`enabled: true, allowed_actions: all`), inheriting Zed's entire CI, which
  contradicts the usual "forks start with Actions off" folklore.
- **`github.com/lucascouts/zeo-workspace`** — private; this repo (docs, scripts, tests).
- The README was replaced (fork commit `b05f68f9be`): the public page was still serving
  Zed's — zed.dev download links, "we're hiring", and a Sponsors section pointing at Zed
  Industries. **Not planned in this story**; authored during publishing.

## Deferred

- Icon artwork is a **placeholder** (reads flat against KDE dark mode) → story 002.
- Packaging (bundle scripts, ebuild `app-editors/zeo`, CLI exposed as the `zeo` command) → story 007.
