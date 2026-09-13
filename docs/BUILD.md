# Building Zeo

There is no Zeo source tree to clone. A Zeo build is the packaged Zed source, plus the
series, compiled once.

## The normal way

```sh
emerge -av app-editors/zeo
```

The ebuild names the commit, applies the patches and sets the build environment. Nothing
below is needed to *use* Zeo — only to iterate on it.

## The development way

```sh
cd zed-patches
bash scripts/prepare-tree.sh <PF>     # unpacks the packaged commit and applies the series
cd work/zed-<commit>
```

`prepare-tree.sh` rebuilds that tree from the distfile Portage already holds, so it costs
nothing to throw away and redo. Expect **~18 GB** for a release build, and tens of minutes
for the first one — `sccache` covers the registry crates, which is where most of the time
is, but not a change to a base crate like `paths`.

```sh
RELEASE_CHANNEL=zeo \
ZED_UPDATE_EXPLANATION='Zeo updates are managed externally' \
cargo build --release --frozen --package zed --package cli
```

`--frozen` = offline and locked: every crate source is cached, no network, no `Cargo.lock`
change.

## The two `RELEASE_CHANNEL`s, which are not the same thing

This one has bitten before, and the symptom is a build that works with the wrong icon:

| | Read by | Decides |
|---|---|---|
| the **env var** `RELEASE_CHANNEL=zeo` | `crates/zed/build.rs`, via `option_env!` | which icon is **embedded in the window** — `zeo` selects `resources/app-icon-zeo.png` |
| the **file** `crates/zed/RELEASE_CHANNEL` | `include_str!` at compile time | the runtime `ReleaseChannel` enum — name, `app_id`, update behaviour |

Set only the file and the window falls back to the dev icon. Set only the env var and the
app still identifies as whatever the file says. **The rebrand patch writes the file; the
build environment must supply the variable** — the ebuild does both.

> **GOTCHA — run `cargo` from inside the tree.** Cargo discovers `.cargo/config.toml` from
> the **current working directory**, not from `--manifest-path`. Building with
> `cargo build --manifest-path work/zed-.../Cargo.toml` from elsewhere silently skips the
> tree's rustflags — among them `--cfg tokio_unstable` — producing a differently
> fingerprinted build and a full rebuild the next time you do it correctly.

**Never set a bare `RUSTFLAGS`**: it replaces the config's flags rather than merging with
them, which drops `tokio_unstable` and breaks the build.

## Output

| | |
|---|---|
| `target/release/zeo` | the application binary (GUI) — launch it directly for a smoke test |
| `target/release/cli` | the thin launcher, installed as the `zeo` **command** |

The cargo bin for the CLI stays `cli`: a second bin named `zeo` would collide in
`target/`. Upstream has the same `cli` → `zed` relationship.

## Installing by hand, for coexistence testing

See [`REBRAND.md`](REBRAND.md) §5. The gotcha recorded there is worth repeating: on KDE
the icon does not appear until `kbuildsycoca6` and `gtk-update-icon-cache` have run. **A
missing icon after install is almost always a stale cache, not a wrong `app_id`.**
