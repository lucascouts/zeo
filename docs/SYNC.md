# Staying current

Zeo has no branch to sync. Staying current means the patch series still applies to the
commit the ebuild packages — and that is `zed-patches`' job, not this repository's.

```bash
cd zed-patches
bash scripts/bump.sh            # refresh, verify, sync (dry run), check - writes nothing
bash scripts/bump.sh --apply    # the same, and the sync writes for real
```

`bump.sh` discovers both versions, gates each step on the previous, and **stops at the
ebuild**: which patches apply, under which USE flag, is the one part of a bump that
encodes intent no script can infer.

To ask whether anything has drifted without changing it:

```bash
bash scripts/status.sh --offline        # from the workspace root
bash zed-patches/scripts/check-sync.sh  # the patches alone
```

## What survived from the fork era

The old model had a daily rebase with a build gate, and one rule worth carrying forward
verbatim — **the tip never points at something that does not build.** On any failure the
old script restored the last-good SHA rather than publishing a half-state.

The patch model keeps the same discipline in a different shape: `verify.sh` applies the
series to a prepared tree and compiles it, and a refreshed series that no longer matches
the ebuild's `PATCHES+=()` makes `bump.sh` exit non-zero and say so. **That exit is the
handoff to a human, not a failure** — deciding which patches apply is the part no script
should guess.

> Everything else from that era is gone: `scripts/sync-upstream.sh`, the `rerere` cache,
> the `zeo-pre-sync` rollback tag, the force-push-with-lease ritual. They belonged to a
> branch that no longer exists. See [`../archive/README.md`](../archive/README.md).
