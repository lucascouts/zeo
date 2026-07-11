# Zeo rebrand — touch-point inventory & rationale

Zeo is a **shallow, openly-identified fork** of the Zed editor (design decision D1):
internal crate/package names stay `zed`; only the user-visible identity layer changes
(display name, release channel, app-id, state dirs, binary name, desktop entry, icon,
URL scheme). This keeps the patch + rebrand stack rebasable onto daily upstream
snapshots. Everything network/back-end (zed.dev servers) is **left as-is** — Zeo has no
backend of its own in this story.

All `fork/` paths below are relative to the fork repo (`fork/`, branch `zeo`).

## 1. Changed — the rebrand commit block (5 commits)

| Concern (commit) | What changed | Rationale / decision |
|---|---|---|
| **Release channel** (`release_channel: add Zeo …`) | New `ReleaseChannel::Zeo` variant; `crates/zed/RELEASE_CHANNEL` = `zeo`; every exhaustive channel-keyed match given a Zeo arm — `display_name`="Zeo", `dev_name`="zeo", `app_id`="dev.zeo.Zeo", `release_query_param`=None, `docs_url`=Stable-like, Windows `app_identifier`="Zeo-Editor", plus arms in auto_update(_ui), client/zed_urls, extension_host/wit, remote_server, zed about-icon, mac_only_instance, zed_credentials_provider. `poll_for_updates(Zeo)=false`. | D2 — own channel; identity resolved exhaustively at compile time (no "unknown channel" runtime state). |
| **Auto-update / remote-server** (`auto_update: neutralize …`) | `check()` shows "updates managed externally" for Zeo and returns; `get_remote_server_release_url(Zeo)=Ok(None)`; `download_remote_server_release(Zeo)` errors before any zed.dev fetch. | D3 — a rebranded fork must never self-replace with an official Zed binary; no zed.dev artifact fetch for `zeo`. |
| **State paths** (`paths: use Zeo state directories`) | `crates/paths/src/paths.rs` `APP_NAME` "Zed"→"Zeo" (single chokepoint): config→`~/.config/zeo`, data→`~/.local/share/zeo`, state/cache/logs/db follow; `Zeo.log`. | D4 — full state separation; coexist with an installed Zed; no fallback reads `~/.config/zed`. |
| **App binary** (`zed: name the application binary zeo`) | `crates/zed/Cargo.toml` `[[bin]] name` + `default-run` → `zeo` (package/crate name stays `zed`). | D9 — app binary `zeo`, no PATH collision with an installed Zed. |
| **Desktop / icon / URL scheme** (`zed: Zeo desktop entry, icons, zeo:// scheme`) | New placeholder icons `resources/app-icon-zeo.png` (512) + `@2x` (1024); `build.rs` window-icon arm `"zeo"=>"-zeo"`; About-window icon → Zeo art; installable `resources/zeo/dev.zeo.Zeo.desktop` + hicolor `dev.zeo.Zeo.png` (512/1024); URL scheme `zed://`→`zeo://` (cli prefix, install_cli `ZED_URL_SCHEME`, macOS `osx_url_schemes`). | D10 — installable identity assets, legally clean placeholder art (not derived from Zed's mark); icon file name == app_id for Wayland resolution; `zeo://` coexists with Zed's `zed://`. |

### Icons
Placeholder art only (final art arrives with story 002). Original geometric "Z" badge,
indigo→teal gradient — **not derived from Zed's trademarked mark**.
- Build resources (window-icon embed + future bundle): `resources/app-icon-zeo.png` (512), `resources/app-icon-zeo@2x.png` (1024).
- Installable (hicolor, name == app_id for Wayland): `resources/zeo/hicolor/{512x512,1024x1024}/apps/dev.zeo.Zeo.png`.

## 2. `dev.zed.Zed*` inventory (Wayland/X11 WM_CLASS + macOS bundle id + packaging)

| Site | Decision |
|---|---|
| `crates/release_channel/src/lib.rs` `app_id()` | **CHANGED** → `dev.zeo.Zeo` (the master constant; Wayland app_id + X11 WM_CLASS). |
| `crates/release_channel/src/lib.rs` Windows `app_identifier()` | **CHANGED** → `Zeo-Editor` (Windows single-instance; completeness — not built on Linux). |
| `crates/zed/Cargo.toml` `[package.metadata.bundle-*]` `identifier` (macOS) | **LEFT** — macOS bundling is story 007 (Linux-only here); tracked below. |
| `script/bundle-linux`, `script/install.sh`, `script/uninstall.sh`, `nix/build.nix`, flatpak/snap ids | **LEFT** — packaging/bundling is **story 007**. Zeo installs manually here (see §5). |
| `crates/cli/src/main.rs` Flatpak `FLATPAK_ID.starts_with("dev.zed.Zed")` | **LEFT** — Flatpak path, story 007. |
| docs prose (`docs/src/*.md`) | **LEFT** — upstream docs; not shipped as Zeo identity. |

## 3. `zed.dev` inventory (network / back-end)

| Group | Decision |
|---|---|
| API/backend mapping (`http_client.rs` `api.zed.dev`/`cloud.zed.dev`/`llm.zed.dev`) | **LEFT** — Zeo uses Zed Industries' servers (no Zeo backend in scope). |
| Default `server_url` (`assets/settings/default.json`, `ZED_SERVER_URL` override) | **LEFT** — same reason; account/collab/AI provider tied to it. |
| Collab base URLs (`crates/collab`) | **LEFT** — server-side crate, not shipped in the client. |
| Docs/help/status/merch links | **LEFT** — Zeo hosts none; a later story may hide these UI entries. |
| Crash reporter (Sentry) | **LEFT (code)** — endpoint is env-injected via `ZED_MINIDUMP_ENDPOINT`; unset = disabled. |
| Update/release-notes URLs | **NEUTRALIZED for Zeo** — auto-update disabled (§1); `release_notes_url(Zeo)` points at `github.com/lucascouts/zeo`. |
| Hosted-AI provider id `"zed.dev"` (settings) | **LEFT** — backend provider identifier, not a display brand. |
| Test fixtures / theme / keymap / docs sample URLs | **LEFT** — not brand config. |
| `zed://` share-link builder (`crates/client/src/zed_urls.rs` `zed://agent/shared/…`) | **LEFT** — deep agent-share links; out of scope (the app registers/handles `zeo://` via the CLI prefix + `.desktop`). |

## 4. Deviations from the story text

- **`ZED_REMOTE_SERVER_PATH` does not exist** in this Zed snapshot (5f8a7413). R3.6's intent
  (no zed.dev fetch + a documented override) is met using the real override
  **`ZED_COPY_REMOTE_SERVER`** (point it at a prebuilt `zed-remote-server`); the error
  message cites it. See `.epic/…/.draft/deviations.yaml`.
- **CLI binary name.** The app binary is `zeo`; the CLI's cargo bin stays `cli` (a second
  `zeo` bin would collide in `target/`). The CLI is exposed as the `zeo` **command** only at
  packaging/install (story 007), mirroring upstream's `cli`→`zed` command relationship.

## 5. Manual install (until story 007 packaging)

For local coexistence testing / the story smoke test (no system package yet):

```sh
# after `cargo build --release` (app binary: fork/target/release/zeo)
install -Dm755 fork/target/release/zeo               ~/.local/bin/zeo
install -Dm644 fork/crates/zed/resources/zeo/dev.zeo.Zeo.desktop \
                                                     ~/.local/share/applications/dev.zeo.Zeo.desktop
install -Dm644 fork/crates/zed/resources/zeo/hicolor/512x512/apps/dev.zeo.Zeo.png \
                                                     ~/.local/share/icons/hicolor/512x512/apps/dev.zeo.Zeo.png
install -Dm644 fork/crates/zed/resources/zeo/hicolor/1024x1024/apps/dev.zeo.Zeo.png \
                                                     ~/.local/share/icons/hicolor/1024x1024/apps/dev.zeo.Zeo.png
update-desktop-database ~/.local/share/applications 2>/dev/null || true
gtk-update-icon-cache -f ~/.local/share/icons/hicolor 2>/dev/null || true
```

Wayland resolves the window icon by matching `app_id` (`dev.zeo.Zeo`) to the installed
icon file name (`dev.zeo.Zeo.png`) and the `.desktop` filename.

## 6. Deferred to story 007 (packaging)

Bundle scripts (`script/bundle-{linux,mac,windows}`, flatpak/snap/nix), `install.sh`/
`uninstall.sh` app-id derivations, macOS `bundle-zeo` metadata + provisionprofile,
Windows `.ico` + resources, and the `dev.zed.Zed`/`zed.dev` sites marked **LEFT** above
that are packaging- or backend-specific.
