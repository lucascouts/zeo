# archive — what the first Zeo attempt left behind

The first run of Zeo was set aside on 2026-08-23 and kept in `ARCHIVED/`, a directory
its own repository gitignored. On 2026-08-27 that directory was removed: 332 MB, of
which everything reproducible has been left out and everything unique is here.

**This is not a backup of the fork**, and as of 2026-09-12 there is no fork to back up:
Zeo was restarted as a patch set over the packaged Zed source, and the fork repository
was deleted and recreated empty. See the root [`README.md`](../README.md).

## What is here

| Path | What | Size |
|---|---|---|
| `epic/` | The story specifications: 001 Fork Foundation and 002 Visual Identity — EARS requirements, design, task breakdowns, deviation registers, authored tests | 404 KB |
| `unpublished-commits/` | The nine commits of story 002 that never reached `origin/zeo`, as `git format-patch` output | 216 KB |
| `art-direction-renders.tar.gz` | 104 PNG renders from the icon exploration rounds | 15 MB |

`epic/` is stored unpacked on purpose: it is the part someone will want to read, search
and diff. The renders are archived because 104 binaries that will never change again
have no business in a git history.

Two files that used to be listed here are gone, each for its own reason:

- **`uncommitted-art.tar.gz`** held the final crystal icon and its SVG source. It was
  unpacked into [`../brand/`](../brand/) on 2026-09-12 and every file verified against
  the hash story 002 recorded for it (`ca89f9…`, the 34 KB final — *not* the
  `72648b…` in `art-directions/checksums-antes.txt`, which is the 204 KB placeholder it
  replaced). Art that a repository versions plainly beats art inside a tarball.
- **`unpublished-commits.bundle`** held the same nine commits with their exact hashes,
  but incrementally: it required `b05f68f9` to already be present, and that commit
  existed only as `origin/zeo` in the deleted repository. It restores nothing now.

## Restoring the nine commits

**The patches are self-sufficient** — that is the whole reason they were kept in two
formats, and the reason one of the two survived the deletion. They apply to any base and
carry author, date and message:

```sh
git am archive/unpublished-commits/*.patch
```

Verified on 2026-08-27, before the original was deleted: applied onto `origin/zeo`
(`b05f68f9`), they produce tree `0fe16cfc08a077d697edb60fc195698a8d009873` — byte for
byte the tree the deleted working copy held. That verification can no longer be
re-run, because its base is gone; what remains valid is the patches' own content.

They are written against Zed snapshot `5f8a7413` and will need refreshing onto whatever
commit is packaged when they are adopted into the series.

> **The lesson, stated once.** A `git bundle` keeps exact hashes and dies with its base.
> `git format-patch` keeps content and reasoning and survives anything. Keep both while
> the base is alive; expect only the second to be there later.

## What was deliberately not kept

`docs/`, `scripts/`, `tests/` and the archive's own `README.md` were left behind: all of
them are in this repository's git history, at commit `d85d58f`, and `docs/` is also
byte-identical to the live `docs/` at the root.
