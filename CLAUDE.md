# zeo — workspace

A **rebranded fork of Zed** with a visual purpose: modern chrome, its own identity, and
eventually a Visual Extension API letting extensions drive the UI. The plan is
[`docs/ROADMAP.md`](docs/ROADMAP.md); the research behind the API is
[`docs/ZEO.md`](docs/ZEO.md); the rebrand's touch points are
[`docs/REBRAND.md`](docs/REBRAND.md).

> **How this project relates to the others: [`../CLAUDE.md`](../CLAUDE.md).**

**Status: archived and restarted (2026-08-23).** The first run is preserved under
`ARCHIVED/` — see [`ARCHIVED/README.md`](ARCHIVED/README.md). The restart has produced
nothing yet: `.epic/` is empty and only `docs/` is tracked.

## How it differs from the rest of this tree

Everything else here patches the *packaged* Zed — small diffs against the exact commit
an ebuild names, verified by `zed-patches`. Zeo instead **carries a fork**, rebased onto
upstream snapshots, and ships as its own installable editor with its own channel,
app-id, state directories and binary name.

The two approaches overlap by subject and not by method, and nothing links them today:
no Zeo change reaches the `bentoo` overlay, and no patch from `zed-patches` is applied
to the Zeo fork by any tooling. Whether they should converge is an open question, not a
settled design.

## The first run was archived, then reduced

`ARCHIVED/` held the first run — 332 MB, including a full Zed fork. It was removed on
2026-08-27 after everything unique in it was extracted into
[`first-run/`](first-run/README.md), 16 MB that this repository versions:

- the **nine commits** of story 002 that never reached `origin/zeo`, as patches proven
  to reproduce the deleted tree byte for byte, plus a bundle keeping their exact hashes;
- the **five art files** that had never been committed anywhere — the final crystal icon
  and its SVG source;
- the **epic specifications** for stories 001 and 002, which were versioned nowhere at
  all before this;
- the 104 icon-exploration renders, archived.

What was left behind was left behind on purpose: `docs/`, `scripts/`, `tests/` and the
archive's own README are all in this repository's history at `d85d58f`.

`fork/` stays gitignored: if the fork returns, it returns as its own repository.
