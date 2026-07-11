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

## Remote topology (`fork/`)

| Remote     | URL                                       | Fetch | Push         |
|------------|-------------------------------------------|-------|--------------|
| `origin`   | `git@github.com:lucascouts/zeo.git`       | yes   | yes (Zeo)    |
| `upstream` | `https://github.com/zed-industries/zed`   | yes   | **DISABLED** |

- `origin` = the user-owned Zeo repository (private); the only valid push target.
- `upstream` = read-only mirror of Zed; its push URL is set to `DISABLED`, so a
  stray `git push upstream` fails fast (D7 — never push to upstream).
- The clone is blobless (`--filter=blob:none`) with full history — required so the
  patch + rebrand commit stack can be rebased onto newer snapshots (never
  `--depth 1`).
- `rerere.enabled=true` — conflict resolutions replay across daily rebases.

## Branch layout

```
zeo = <pinned snapshot commit>
        └─ 7 patch commits (0001, 0002, 0005–0009)
             └─ rebrand commit block (channel / auto-update / paths / bin / desktop+icon)
```

Daily sync rebases the patch + rebrand stack onto the new `upstream/main` tip.

## Sync policy (D6)

Fetch `upstream` → rebase `zeo` onto the new snapshot → build gate. On conflict
or build breakage, `zeo` stays pinned at the last-good SHA until manually
resolved. The executable procedure is [`../scripts/sync-upstream.sh`](../scripts/sync-upstream.sh);
see [`SYNC.md`](SYNC.md).
