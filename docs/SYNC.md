# Upstream sync — procedure, pin policy, conflict playbook

Zeo is a rebase-based fork: the branch `zeo` is **upstream snapshot + patch commits +
rebrand commits**. Keeping current means rebasing that stack onto a newer
`upstream/main`. This is designed to be run daily and to **fail safely**.

See [`UPSTREAM.md`](UPSTREAM.md) for the fork base and remote topology.

## The script

```sh
scripts/sync-upstream.sh [--repo <path>] [--to <ref>] [--build-cmd <cmd>]
```

| Flag | Default | Meaning |
|---|---|---|
| `--repo` | `fork` | the fork repository |
| `--to` | `upstream/main` | ref to rebase onto |
| `--build-cmd` | `cargo check` | the build gate run after the rebase |

Everyday use:

```sh
./scripts/sync-upstream.sh
```

The default gate is a fast `cargo check`. Use the real release build when you want a
stronger guarantee (slower):

```sh
./scripts/sync-upstream.sh \
  --build-cmd 'RELEASE_CHANNEL=zeo cargo build --release --frozen -p zed -p cli'
```

## Flow

1. `git fetch <remote of --to>`
2. Tag the current `zeo` tip as `zeo-pre-sync` (the rollback point)
3. `git rebase <--to>` with `rerere` enabled
4. Run the build gate in the repo
5. On success: record the new tip in `<repo>/.git/zeo-last-good`, drop the tag

## Outcomes

| Outcome | Branch `zeo` | Exit | Left behind |
|---|---|---|---|
| **Clean** — rebase applies, gate passes | on the new upstream tip | `0` | `.git/zeo-last-good` = new tip |
| **Conflict** — rebase hits a conflict | **unchanged**, at the last-good SHA | non-zero | nothing (rebase aborted, tag dropped) |
| **Gate failure** — rebase applies, build breaks | **restored** to the pre-sync SHA | non-zero | nothing |

In every outcome the script leaves **no `zeo-pre-sync` tag and no rebase state**, and the
working tree clean (R5.4). The only artefact is the last-good marker.

## Pin policy (D6)

**A failed sync is non-blocking for users and blocking for the branch tip.** `zeo` never
points at a commit that does not build: on any failure it stays pinned at the last-good
SHA until a human resolves it. Nothing is force-pushed and no partial state is published.

## Conflict playbook

When the script reports a conflict, the rebase has already been aborted and `zeo` is back
at its last-good SHA. Resolve it deliberately:

```sh
cd fork
git fetch upstream
git tag -f zeo-pre-sync zeo          # your own rollback point
git rebase upstream/main             # let it stop on the conflict

# ... resolve the conflicted files, then:
git add -A
git rebase --continue                # repeat until the rebase finishes

# gate it before trusting the tip:
RELEASE_CHANNEL=zeo cargo build --release --frozen -p zed -p cli

# happy? drop the rollback tag. unhappy?  git reset --hard zeo-pre-sync
git tag -d zeo-pre-sync
```

`rerere` is enabled in the fork, so each resolution you make is recorded and **replayed
automatically** on the next rebase that hits the same conflict — daily syncs get cheaper
over time.

If a conflict is not worth resolving right now, simply do nothing: `zeo` stays on the last
known-good snapshot and Zeo keeps building.

## Where the patches live

The overlay `.patch` files seeded the initial 7 commits and are **no longer the source of
truth** (design D5). Changes now land as ordinary commits on `zeo`.

## Tests

The script's contract is pinned by an integration test that builds real git fixtures and
exercises all three outcomes (clean, conflict, gate failure) plus the no-residue rule:

```sh
bash tests/sync-upstream.test.sh
```
