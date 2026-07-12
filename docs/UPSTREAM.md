# Upstream tracking — Zeo fork base

Zeo is an openly-identified fork of the Zed editor. The fork source lives in the
gitignored `fork/` directory (its own git repository); this file records the base
snapshot and remote topology `fork/` is configured with.

## Fork base snapshot

- **Upstream:** `zed-industries/zed`
- **Pinned base commit (branch `zeo` starts here):**
  `5f8a7413a31769e0882357f90dc424b3962ac72d`
- **Commit subject:** `Update Zed-hosted model documentation (#60771)`
- **Provenance:** the exact commit pinned by the bentoo overlay ebuild
  `app-editors/zed/zed-1.12.0_pre20260710-r2.ebuild`
  (`EGIT_COMMIT="5f8a7413a31769e0882357f90dc424b3962ac72d"`) — the snapshot the 7
  overlay patches are known to apply against cleanly.

## The two repositories

| Repo | What | Visibility |
|---|---|---|
| [`lucascouts/zeo`](https://github.com/lucascouts/zeo) | the editor — a **real GitHub fork** of `zed-industries/zed`; default branch `zeo` | **public** |
| [`lucascouts/zeo-workspace`](https://github.com/lucascouts/zeo-workspace) | this repo — docs, scripts, tests, roadmap | private |

`zeo` is a **fork**, not a plain repository, and that is load-bearing: a fork shares
its object store with the upstream network, so publishing the commit stack pushes only
those commits (megabytes) instead of re-uploading Zed's whole history (gigabytes) —
which a blobless clone could not do anyway without re-fetching every blob first.

Two consequences, both permanent:

- **The fork is necessarily public.** A fork of a public repository cannot be made
  private. Leaving the fork network later (dropping the "forked from" badge) requires a
  GitHub Support ticket — it is not self-service. This is a conscious trade: Zeo is an
  openly-identified fork (story Overview; design "Security Considerations → Trademark").
  It is **not** decision D1 — D1 is the shallow-rebrand rule.
- **GitHub Actions must stay OFF.** The fork inherits Zed's entire `.github/workflows/`.
  Contrary to folklore, the fork did **not** arrive with Actions disabled — the API
  reported `enabled: true, allowed_actions: all`, and it had to be turned off explicitly
  (`gh api -X PUT repos/lucascouts/zeo/actions/permissions -F enabled=false`). Left on,
  Zed's CI fires on every push, fails for want of secrets, and burns minutes. Re-check
  this after any repository transfer or settings reset.

## Dependabot: alerts are telemetry, updates are forbidden

Dependency graph and **Dependabot alerts** are ON. **Dependabot security updates** are OFF,
and they stay OFF.

The distinction is the whole point. Zed's `Cargo.lock` carries ~1850 packages, **none of
them ours** — Zeo adds one local path crate and not a single third-party dependency. So:

- **An alert is information, not a task.** Every alert Zeo receives exists identically on
  `zed-industries/zed`; it is Zed's dependency, on Zed's schedule. The correct response is
  usually **none**: when upstream bumps, the fix arrives for free on the next rebase.
- **Security updates would open PRs against `Cargo.lock`** — breaking the `--frozen`
  build contract (design: no new dependencies) *and* planting a permanent conflict in a hot
  file that every daily rebase has to fight. That is why the setting is disabled.

> ⛔ **Never click "Create Dependabot security update"** on an alert, and never enable
> Dependabot security updates. GitHub offers both prominently and they look like the
> helpful thing to do. They are not: a dependency bump of our own is a fork of Zed's
> dependency tree, which is precisely the maintenance cost D1 (shallow rebrand) exists to
> avoid.

**The escape hatch**, so it is a decision and not a temptation: a *critical* CVE, in a code
path Zeo actually reaches, left unfixed upstream for long enough to matter. Then bump it
locally — as a registered deviation, accepting that it conflicts on every rebase until
upstream catches up. Rare by construction. Anything short of that bar: wait for the rebase.

## Remote topology (`fork/`)

| Remote     | URL                                       | Fetch | Push         |
|------------|-------------------------------------------|-------|--------------|
| `origin`   | `git@github.com:lucascouts/zeo.git`       | yes   | yes (Zeo)    |
| `upstream` | `https://github.com/zed-industries/zed`   | yes   | **DISABLED** |

- `origin` = the Zeo fork; the only valid push target.
- `upstream` = read-only mirror of Zed; its push URL is set to `DISABLED`, so a
  stray `git push upstream` fails fast (D7 — never push to upstream).
- The clone is blobless (`--filter=blob:none`) with full history — required so the
  patch + rebrand commit stack can be rebased onto newer snapshots (never
  `--depth 1`).
- `rerere.enabled=true` — conflict resolutions replay across daily rebases.
- Commits land on `zeo` only. The fork's `main` is left alone as an upstream mirror and
  will simply go stale — that is fine and expected.

## Branch layout

```
zeo = <pinned snapshot commit>
        └─ 7 patch commits (0001, 0002, 0005–0009)
             └─ rebrand commit block (channel / auto-update / paths / bin / desktop+icon)
                  └─ 3 follow-ups (clippy-clean of the patch-0002 crate; startup-log
                     rebrand; README)
```

`README.md` is a hot upstream file, so it will conflict whenever Zed touches it — accepted,
because the public repo page has to be Zeo's, not Zed's. `rerere` replays the resolution.

Daily sync rebases the patch + rebrand stack onto the new `upstream/main` tip.

## Patch import (one-shot, already done)

The 7 overlay patches were imported as commits with `git am`, in series order —
the numbering has a real gap, 0003 and 0004 **do not exist**, so never glob blindly:

```sh
cd fork && git switch zeo
git am /path/to/overlay/app-editors/zed/files/000{1,2,5,6,7,8,9}-*.patch
```

**Failure semantics (R2.3).** Atomicity here is guaranteed by `git am` itself, not by
any script in this repo: on a failing patch `git am` stops and `git am --abort` restores
the pre-import tip — the branch never retains a partially-applied series. There is
deliberately no import script: the import is a completed one-shot, and inventing a
wrapper for it would add a code path nobody runs.

**This abort path was never exercised.** All 7 patches applied clean on the first try.
The requirement is satisfied by the tool's semantics, not by observed behaviour — stated
plainly here rather than left implied, so nobody later mistakes it for a tested path.

**Re-importing (future contributor).** If the stack is ever rebuilt from scratch, run the
`git am` above from the pinned base. Patch 0002 is a plain diff with no mailbox headers,
so `git am` cannot carry authorship for it — it is committed on import with a message
recording that fact. The other 6 are `format-patch` output and preserve original
authorship and messages.

## Sync policy (D6)

Fetch `upstream` → rebase `zeo` onto the new snapshot → build gate. On conflict
or build breakage, `zeo` stays pinned at the last-good SHA until manually
resolved. The executable procedure is [`../scripts/sync-upstream.sh`](../scripts/sync-upstream.sh);
see [`SYNC.md`](SYNC.md).

### ⛔ Never use GitHub's "Sync fork" button

With the default branch set to `zeo` on a fork, GitHub offers a prominent **Sync fork**
button. It merges (or hard-resets to) `zed:main` — either one destroys the linear
rebase stack that D6 exists to protect, and it gives no meaningful warning.
**Syncing happens only through `scripts/sync-upstream.sh`.**

### Publishing after a sync

A rebase rewrites the stack, so the post-sync push is a force-push. Always fetch first:

```sh
git fetch origin
git push origin zeo:refs/backups/zeo-$(date +%F)   # cheap server-side rollback point
git push --force-with-lease origin zeo
```

`--force-with-lease` compares against the **local** remote-tracking ref. Without the
preceding `fetch`, that ref may be stale, and the lease then guards nothing while
looking like it does — a false safety. The backup ref costs nothing (same object
network) and is what you rewind to if a force-push ever eats a commit.
