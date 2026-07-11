# Building Zeo locally (release)

Zeo builds from the fork checkout (`fork/`, branch `zeo`) with the upstream Zed
toolchain plus a couple of Zeo-specific environment variables. Packaging/installation
is out of scope here (story 007).

## Prerequisites

- Rust system toolchain **≥ 1.95** (the fork pins `1.95.0` in `rust-toolchain.toml`; the
  Gentoo system `rustc`/`cargo` — 1.96.1 here — satisfies the minimum). `cargo` and
  `rustc` on `PATH`.
- The build compiles a large native graph (gpui, tree-sitter grammars, `libwebrtc` via
  `webrtc-sys`, wasmtime, resvg/skia, …). System build dependencies are the same as
  upstream Zed's — present on the Gentoo host via the `app-editors/zed` ebuild's `DEPEND`.
  `libwebrtc` is built/fetched by `webrtc-sys` locally; **no `LK_CUSTOM_WEBRTC` is needed**
  (the ebuild sets that only for its sandboxed prebuilt path).
- Disk: the release `target/` is tens of GB.

## Environment

The fork's `.cargo/config.toml` already supplies the mandatory rustflags —
`--cfg tokio_unstable` and `-C symbol-mangling-version=v0` — and the `lld` linker.
**Do not set a bare `RUSTFLAGS` env var**: it overrides (rather than merges with) the
config and would drop `tokio_unstable`, breaking the build.

> **GOTCHA — run cargo from inside `fork/`.** Cargo discovers `.cargo/config.toml` from the
> **current working directory**, not from `--manifest-path`. Invoking
> `cargo build --manifest-path fork/Cargo.toml` from the workspace root silently **skips**
> the fork's rustflags, producing a differently-fingerprinted build (and a full rebuild the
> next time you build correctly). Always `cd fork` first — which is what
> `scripts/sync-upstream.sh` does for its build gate.

Zeo-specific build env:

| Var | Required | Why |
|---|---|---|
| `RELEASE_CHANNEL=zeo` | **yes** | `crates/zed/build.rs` reads the RELEASE_CHANNEL **env var** (`option_env!`) to pick the embedded window icon; `zeo` → `resources/app-icon-zeo.png`. This is separate from the `crates/zed/RELEASE_CHANNEL` **file** (which drives the runtime `ReleaseChannel` enum via `include_str!`). Without the env, the window icon falls back to the dev icon. |
| `ZED_UPDATE_EXPLANATION='Zeo updates are managed externally'` | optional | The "Check for Updates" action is already channel-neutralized for Zeo in code; setting this matches packaged builds and also suppresses any update polling. |
| `RELEASE_VERSION=1.12.0_pre20260710` | optional | Version string (the pinned snapshot). |

## Build

```sh
cd fork
RELEASE_CHANNEL=zeo \
ZED_UPDATE_EXPLANATION='Zeo updates are managed externally' \
RELEASE_VERSION=1.12.0_pre20260710 \
cargo build --release --frozen --package zed --package cli
```

`--frozen` = offline + locked (all crate sources are already cached; no network for crate
downloads, no `Cargo.lock` changes). Upstream Zed's `[profile.release]` is
`lto = "thin"`, `codegen-units = 1`, `debug = "limited"` — a full first release build is
long (tens of minutes); incremental rebuilds are fast.

## Output

- `fork/target/release/zeo` — the Zeo **application** binary (GUI). Launch it directly
  under Wayland for the smoke test.
- `fork/target/release/cli` — the thin CLI launcher (exposed as the `zeo` **command** at
  packaging time, story 007).

## Notes

- The ebuild appends `-C link-args=…-rpath,$ORIGIN/../lib` for the installed `/usr`
  layout; a local build run from `target/release/` does not need it.
- To speed up iteration you may export `CARGO_PROFILE_RELEASE_LTO=off` (or `thin`); the
  release-build acceptance (R4.1) uses the repo default.
- Manual install of the desktop entry + icons for coexistence testing: see
  [`REBRAND.md`](REBRAND.md) §5.
