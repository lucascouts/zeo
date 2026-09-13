# zeo — the brand, and the plan that uses it

Zeo is a **rebranded Zed**, delivered as a patch series over the exact Zed commit the
`bentoo` overlay packages. It is deliberately **not a fork**: there is no vendored Zed
here, no branch to rebase, no merge debt. What this repository holds is the brand, the
specification, and the reasoning — the patches themselves live in `zed-patches`.

> **How this project relates to the others: [`../CLAUDE.md`](../CLAUDE.md).**

| | |
|---|---|
| the plan | [`docs/ROADMAP.md`](docs/ROADMAP.md) |
| what the rebrand touches, and why | [`docs/REBRAND.md`](docs/REBRAND.md) |
| the Visual Extension API research | [`docs/ZEO.md`](docs/ZEO.md) |
| the mark, and the script that builds it | [`brand/`](brand/) |
| the first attempt, kept as a record | [`archive/`](archive/) |

## The shape changed on 2026-09-12, and every doc here had to follow

Zeo's first run (2026-07 to 2026-08) **carried a fork**: a real GitHub fork of
`zed-industries/zed`, branch `zeo`, a twelve-commit stack rebased onto a new upstream
snapshot daily by `scripts/sync-upstream.sh`. That shape was abandoned, and the fork
repository was deleted and recreated as a plain, empty, non-fork repository.

The reason is the one the rest of this tree already proved: **a patch series states what
it changes and fails loudly when upstream moves; a fork accumulates a debt that grows
with every release.** `zed-patches` has carried sixteen patches - numbered to 0018, with
real gaps - across daily snapshot bumps, `refresh.sh` preserving each patch's reasoning
as it rebuilds the diff. The Zeo fork, on the same
calendar, went three weeks without a rebase and was six snapshots behind when it was
retired.

**Read the git history of `docs/` before trusting an old sentence about Zeo.** Anything
describing `fork/`, `upstream/main`, `rerere`, or a daily rebase is from the first run.

## What survived the change, and what did not

| | |
|---|---|
| **the mark** | survived whole — `brand/build-icon.py` *constructs* it, so it is reproducible rather than merely stored |
| **`docs/REBRAND.md`** | survived whole: it is an inventory of constants and decisions, and constants do not care how the diff is delivered |
| **story 002's nine commits** | survived as `format-patch` in `archive/unpublished-commits/`, against snapshot `5f8a7413`; they need refreshing before adoption |
| **story 001's five commits** | **did not survive** — they existed only in the deleted repository. `REBRAND.md` §1 documents all five, row by row, with rationale, so what was lost is the diff and not the reasoning |
| **`scripts/sync-upstream.sh`** and its tests | gone with the fork model; `zed-patches`' `refresh.sh` and `bump.sh` do that job now |

## Standing rules

- **Crate names stay `zed`.** The rebrand is an identity layer — `APP_NAME`, the
  `ReleaseChannel` variant, the `[[bin]]` name, icons, `.desktop`, `zeo://`. Renaming
  crates buys nothing a user can see and costs a conflict on every refresh.
- **The WIT package `zed:extension` never changes.** It is the ABI every Zed extension
  imports; renaming it stops every existing extension from loading.
- `.epic/` is never committed.
- Written artefacts are in English.
- Zeo is not affiliated with Zed Industries, and the README says so in those words.
