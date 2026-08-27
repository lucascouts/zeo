# first-run — what the archived Zeo attempt left behind

The first run of Zeo was set aside on 2026-08-23 and kept in `ARCHIVED/`, a directory
its own repository gitignored. On 2026-08-27 that directory was removed: 332 MB, of
which everything reproducible has been left out and everything unique is here, in 16 MB.

**This is not a backup of the fork.** The Zed fork itself is reproducible — it is
upstream Zed plus published history plus what is recorded below.

## What is here

| Path | What | Size |
|---|---|---|
| `epic/` | The story specifications: 001 Fork Foundation and 002 Visual Identity — EARS requirements, design, task breakdowns, deviation registers, authored tests | 404 KB |
| `unpublished-commits/` | The nine commits of story 002 that never reached `origin/zeo`, as `git format-patch` output | 216 KB |
| `unpublished-commits.bundle` | The same nine commits as a git bundle, preserving their exact hashes | 60 KB |
| `art-direction-renders.tar.gz` | 104 PNG renders from the icon exploration rounds | 15 MB |
| `uncommitted-art.tar.gz` | The final crystal icon and its SVG source — five files that were never committed anywhere | 268 KB |

`epic/` is stored unpacked on purpose: it is the part someone will want to read, search
and diff. The renders are archived because 104 binaries that will never change again
have no business in a git history.

## Restoring the nine commits

Two formats, because they fail in different ways.

**The patches are self-sufficient.** They apply to any base and carry author, date and
message:

```sh
git am first-run/unpublished-commits/*.patch
```

Verified on 2026-08-27, before the original was deleted: applied onto `origin/zeo`
(`b05f68f9`), they produce tree `0fe16cfc08a077d697edb60fc195698a8d009873` — byte for
byte the tree the deleted working copy held.

**The bundle preserves the exact commit hashes**, but it is incremental: it carries only
those nine commits and needs `b05f68f9` already present. That commit *is* `origin/zeo`
at `github.com/lucascouts/zeo`, so the bundle works against a clone of that repository
and against nothing else:

```sh
git clone git@github.com:lucascouts/zeo.git && cd zeo
git fetch ../first-run/unpublished-commits.bundle 'refs/heads/*:refs/heads/*'
```

A bundle verified as valid is not a bundle that restores: `git bundle verify` passes on
this file inside a repository that already has the base, and fails in an empty one. That
is why the patches are here too.

## What was deliberately not kept

`docs/`, `scripts/`, `tests/` and the archive's own `README.md` were left behind: all of
them are in this repository's git history, at commit `d85d58f`, and `docs/` is also
byte-identical to the live `docs/` at the root.
