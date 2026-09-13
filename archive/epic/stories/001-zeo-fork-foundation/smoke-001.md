# Smoke checklist — story 001 (sub-task 5.3, Wayland, manual)

**Status: ✅ ALL 8 ITEMS PASS — 5.3 complete.**

- Binary: `fork/target/release/zeo`, built with `RELEASE_CHANNEL=zeo`, at commit `f7218425`.
- Session: KDE Plasma / Wayland (`WAYLAND_DISPLAY=wayland-0`), NVIDIA GTX 1050 Ti (Vulkan).
- Coexisting Zed: `app-editors/zed-1.12.0_pre20260710-r1` (CLI `zedit`, app `/usr/libexec/zed-editor`).
- Identity assets installed to `~/.local/share/{applications,icons/hicolor/…}` + `~/.local/bin/zeo`.

## Results

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Window/About shows "Zeo" + channel `zeo` | ✅ | About: `Zeo 1.12.0` · `Version: 1.12.0+zeo.f7218425ad…`. The `+zeo` pre-release tag comes from `dev_name()`. **R3.1** — this About string is the load-bearing evidence, and it comes from the `release_channel` commit `6c555074aa` alone. _(Corroboration only, NOT evidence: the startup log `[zeo] ===== starting zeo version … =====`. It is produced by commit `f7218425ad`, which exists for no other reason — citing it here would be circular. See deviation D-005.)_ |
| 2 | Compositor app_id `dev.zeo.Zeo` + icon resolves | ✅ | Zeo icon renders in the KDE task bar/window. Wayland only resolves it when `app_id` == `.desktop` filename == icon filename, so this transitively proves the app_id. **R3.2** |
| 3 | `~/.config/zeo` + `~/.local/share/zeo` created | ✅ | Both exist (plus `~/.cache/zeo`, seen in the crash-handler path). `node_runtime` scratch dir: `/home/otaku/.local/share/zeo/node`. **R3.3** |
| 4 | `~/.config/zed` unchanged while both apps ran | ✅ | sha256 of the whole tree identical before/after: `52ea8aa9a7cb4c2670336416a3f504503bf1549a6691450f4886eeee7e9d5d3d`. Nothing under Zed's dirs modified. **R3.4** |
| 5 | Binaries named `zeo`, no PATH collision | ✅ | Zeo: `zeo` (app). Zed: `zedit` (CLI) + `/usr/libexec/zed-editor` (app). Disjoint names. **R3.7** |
| 6 | Agent panel: 0007 manual-mode badge + 0008 clickable attachments | ✅ | Manual-mode badge ("wait for approval / Manual") present; file attachments/mentions clickable in replayed messages. **R4.3** |
| 7 | Manual update check: "updates managed externally", no download | ✅ | Dialog: *"Zeo updates are managed externally — install or update Zeo through your package manager or by rebuilding the `zeo` branch."* — exactly the channel-keyed arm added in 4.2; no download path reachable. **R3.5** |
| 8 | `xdg-mime query default x-scheme-handler/zeo` | ✅ | → `dev.zeo.Zeo.desktop` |

### Interface check (design §4 ↔ §6)

✅ All four agree on `dev.zeo.Zeo`:

```
.desktop  Icon=dev.zeo.Zeo
.desktop  StartupWMClass=dev.zeo.Zeo
icon file ~/.local/share/icons/hicolor/512x512/apps/dev.zeo.Zeo.png
compiled  release_channel/src/lib.rs:230  ReleaseChannel::Zeo => "dev.zeo.Zeo"
```

## Findings (non-blocking)

1. **Install gotcha (folded into REBRAND.md §5):** on KDE the icon does **not** resolve until
   `kbuildsycoca6` (rebuilds the desktop-file cache) and `gtk-update-icon-cache` are run after
   installing the assets. The first launch showed no icon purely because of this stale cache —
   not an app_id problem.
2. **hicolor sizes:** `hicolor/index.theme` declares up to `512x512/apps`; `1024x1024` is **not**
   declared, so the 1024 px asset is kept as a master but is never used by theme lookup. This
   mirrors how the overlay Zed ships its own icons.
3. **Placeholder art readability:** the icon reads as washed-out/flat against KDE's dark mode
   (light badge). Expected — the art is a placeholder (D10); **feed into story 002** (visual
   identity / final artwork).
4. **ACP client name stays `"zed"`** (`agent_servers/src/acp.rs:925,977`): it is a protocol
   identity the agent may key behaviour off, not a brand string. Deliberately not renamed.
