# Upstream tracking — what Zeo is pinned to

Zeo is an openly-identified rebrand of the Zed editor, delivered as patches. There is no
Zeo copy of Zed's source: the base is whatever commit the `bentoo` overlay's
`app-editors/zeo` names, and the patches are written against that commit.

## The pin is the ebuild, not a branch

| | |
|---|---|
| **Upstream** | `zed-industries/zed` |
| **The pin** | `EGIT_COMMIT` in `app-editors/zeo` |
| **Where the patches live** | [`lucascouts/zed-patches`](https://github.com/lucascouts/zed-patches), under `patches/<PF>/` |
| **A tree to build against** | `zed-patches/scripts/prepare-tree.sh <PF>` — disposable, rebuildable |

**Never hardcode the commit anywhere else.** The scripts all parse it out of the ebuild,
which is what keeps a bump from having to be repeated in five places.

When the packaged commit moves, `refresh.sh` rebuilds each patch's diff against the new
base while preserving everything above the `---` in its header — so the *reasoning* a
patch carries survives a bump that its *diff* does not.

> **This replaced a fork.** Until 2026-09-12 Zeo tracked upstream by rebasing a
> twelve-commit stack onto `upstream/main` daily, through `scripts/sync-upstream.sh`.
> That model, its `rerere` cache, its remote topology and its force-push discipline are
> gone. If you find a document here describing them, it is from the first run — see
> [`../archive/README.md`](../archive/README.md).

## Never push to upstream

`zed-industries/zed` is a third party's repository. Nothing here ever pushes there.
Upstream contribution, if it happens, is a pull request opened deliberately — never a
side effect of a misconfigured remote.

## Dependency alerts are telemetry, not tasks

Zed's `Cargo.lock` carries roughly 1850 packages, **none of them Zeo's** — the rebrand
adds no third-party dependency at all. The consequence is worth stating because the
tooling will keep suggesting otherwise:

- **An alert on a Zed dependency is information.** It exists identically upstream, on
  Zed's schedule. Usually the correct response is none: when upstream bumps, the fix
  arrives with the next packaged commit.
- **An automated dependency PR would be actively harmful.** It breaks the `--frozen`
  build contract and plants a permanent conflict in a hot file that every refresh has to
  fight. A dependency bump of our own is a fork of Zed's dependency tree — precisely the
  maintenance cost the shallow-rebrand rule (D1) exists to avoid.

**The escape hatch**, so this is a decision and not a temptation: a *critical* CVE, in a
code path Zeo actually reaches, left unfixed upstream long enough to matter. Then bump it
as a registered deviation, accepting the conflict until upstream catches up. Rare by
construction. Anything short of that bar: wait.

## A gotcha the series inherited

**The patch numbering has real gaps — never glob blindly.** `0003` and `0004` were
dropped when upstream superseded them, and the series still runs `0001, 0002, 0005…`.
A `files/0*.patch` glob silently picks up whatever is on disk, including patches a USE
flag was supposed to exclude. The ebuild's `PATCHES+=()` names each file explicitly for
this reason, and `check-sync.sh` proves the list and the directory agree.
