# ZEO.md — Visual Extension API for Zed (session handoff)

> Full context of the 2026-07-10 conversation about creating, via our own patches, a UI
> API for Zed extensions. Continuation document for a new session.

---

## 1. Original question and context

The user asked whether it is possible to edit the UI of the Agent Panel / the Zed
editor, how **GPUI** works and whether it uses JavaScript. Then, whether VSCode has a
"UI API", whether any such initiative exists in Zed, and finally decided: **"let's
create our own patches to support this ourselves"**.

### Established base facts

- **GPUI** = Zed Industries' UI framework, pure Rust, 100% GPU rendering
  (Metal/macOS, **Vulkan via `blade`/Linux**, DirectX/Windows). Zero JavaScript/HTML/
  Electron. Declarative model (views with the `Render` trait, Tailwind-style fluent
  API, `Entity<T>` + contexts), immediate/retained hybrid. Glyphs rasterized into an
  atlas; everything else becomes quads/paths.
- **Zed has no UI API for extensions today**: extensions are WASM (wasmtime) limited to
  languages, themes, slash commands, context servers (MCP), debug adapters, agent
  servers. No access to GPUI/window/panels.
- **VSCode** (comparison): declarative contribution points + **webviews** (sandboxed
  iframe with free HTML/JS — that is how the Claude Code panel works there). The
  workbench chrome is locked down on purpose. In Zed via ACP, the UI is native (GPUI)
  and the adapter only speaks protocol — hence this workspace's patch series to close
  UI gaps.

### Relevant Zed code (UI)

- Agent Panel: `crates/agent_ui/` (`agent_panel.rs`, `message_editor.rs`, `acp/thread_view.rs`)
- Editor/workspace: `crates/editor/`, `crates/workspace/`, components in `crates/ui/`

---

## 2. Research: existing initiatives (GitHub)

**No PR exists. Discussions only. Official position: "on the radar, but not in the near future".**

| Item | What | Status |
|---|---|---|
| [RFC #53403 — Visual Extension API](https://github.com/zed-industries/zed/discussions/53403) (Apr/2026, ~40+ upvotes) | Proposes WIT for panels, status bar items and views via GPUI (not webview). Detailed pseudocode (see §3) | Maintainer **macraig** (May/2026): *"needs to be driven by our team… significant undertaking, not something we're likely to get to in the near future"* |
| [#48015 — UI modifications via extensions using GPUI](https://github.com/zed-industries/zed/discussions/48015) (Jan/2026) | Status bar buttons, panels, native tables/grids | Open, no maintainer response |
| [#37270 — custom rendering of documents](https://github.com/zed-industries/zed/discussions/37270) | **The most important technically**: acknowledges that WASM has zero GPUI access; the realistic path = a **declarative protocol** (the extension describes UI as data, Zed renders it natively) | Discussion |
| [#17325 — Custom Views in Extension API](https://github.com/zed-industries/zed/issues/17325) (Sep/2024) | Custom views via GPUI | Closed `state:unactionable` |
| [#6679 — GPUI2 and extensions](https://github.com/zed-industries/zed/discussions/6679) | Historical discussion (GPUI2 era) | Old |

Zed's recent extensibility work went to other fronts (debug adapters, context
servers/MCP, agent servers/ACP, icon themes) — never UI. The community is frustrated
with the AI-first prioritization.

---

## 3. RFC #53403 sketch (API reference)

```wit
// Panels
enum panel-position { left-sidebar, right-sidebar, bottom-panel }
record panel-info { id: string, name: string, icon: option<string>,
                    position: panel-position, default-visible: bool }
resource panel-handle {
    update: func(content: element-tree) -> result<_, string>;
    set-visible: func(visible: bool);  is-visible: func() -> bool;
}
register-panel: func(info: panel-info) -> result<panel-handle, string>;

// Status bar
record status-item { id: string, content: status-content, priority: i32,
                     tooltip: option<string>, on-click: option<callback-id> }
variant status-content { text(string), icon(string), text-with-icon(string, string) }
add-item: func(item: status-item) -> result<status-item-handle, string>;
```

- Variant-based element tree: container, text, button, text-input, table, list, icon.
- Proposed phases: **1** status bar (1-2 wk) → **2** read-only panels (3-4 wk) →
  **3** interactive (6-8 wk) → **4** advanced rendering (2-3 months).
- Security: WASM sandbox kept, predefined components (no arbitrary HTML/CSS),
  frame budget with auto-disable, size/count limits.
- Objection in the thread (nakajimayoshi): expose GPUI directly via a Rust trait —
  **dismissed** in our analysis (unfeasible in the WASM sandbox, unsafe). The right
  direction = declarative (#37270), the same principle as ACP.

---

## 4. Mapping of the real Zed code (subagent, clone @ `5f8a7413a31769`, 2026-07-10)

> The sparse clone lived in a session scratchpad (ephemeral). To recreate:
> `git clone --filter=blob:none --sparse --depth 1 https://github.com/zed-industries/zed`
> `git sparse-checkout set crates/extension_api crates/extension crates/extension_host crates/agent_ui/src crates/workspace/src crates/zed/src`

### a) Extension runtime

- **wasmtime (component model) + WASI**, in-process. Host: `crates/extension_host/src/wasm_host.rs`
  (`WasmHost` :48-60; engine with `epoch_interruption(true)` + epoch thread :546-585;
  cooperative yield per tick — the UI never blocks :660-675).
- Loading: `load_extension` :633-727 — reads the API version from the custom section
  `zed:api-version` (the guest writes it in `crates/extension_api/src/extension_api.rs:351-353`;
  parsed at `crates/extension/src/extension.rs:184`), calls `init-extension` :687, runs a
  per-extension **message loop** (mpsc of `ExtensionCall` closures :691-696).
- FS sandbox: WASI with only the extension's work-dir preopened (:729-751).
- Orchestration: `ExtensionStore` (`extension_host.rs:129`, init :265); post-load
  registration :1531-1573 (LSP :1538, context servers :1548, debug adapters :1561),
  `ExtensionsInstalledChanged` event :1580-1584.

### b) Versioned WIT (key for the patch)

- Guest: `crates/extension_api/wit/since_v{0.0.1 … 0.8.0}/` — dirs **immutable per
  version**. 0.8.0 has: extension.wit, common.wit, context-server.wit, dap.wit,
  github.wit, http-client.wit, lsp.wit, nodejs.wit, platform.wit, process.wit,
  slash-command.wit.
- Mirrored host: `crates/extension_host/src/wasm_host/wit/since_v0_x_y.rs` (10 modules),
  `Extension` dispatch enum (wit.rs:94-104), `instantiate_async` cascade (wit.rs:118-205).
- **Channel gate**: `wasm_api_version_range` (wit.rs:60-70) — Stable/Preview accept at
  most `0.7.0`; 0.8.0 is Dev/Nightly-only (since_v0_8_0.rs:33-34). **The patch needs 1
  line in wit.rs:66** (or run dev/nightly).
- **Upstream has pending breaking changes** in `crates/extension_api/PENDING_CHANGES.md`
  for the next version → **use `since_v0.9.9/` in the fork** to avoid colliding with
  their 0.9.0.

### c) Capabilities

- `ExtensionManifest.capabilities` (`extension_manifest.rs:114`); enum in
  `crates/extension/src/capabilities.rs:14-20` (`process:exec`, `download_file`,
  `npm:install`).
- Double check: the manifest declares **and** the user grants via settings
  (`granted_capabilities`, `extension_settings.rs:18,43-58` → wasm_host.rs:627), enforced
  by `CapabilityGranter` (`capability_granter.rs:23-48`). **`ui:status_item`/`ui:panel`
  fit this mold with no structural change.**

### d) Host↔extension communication

- Host→ext: only on-demand WIT exports via `WasmExtension::call` (wasm_host.rs:872-901).
  **There are no events/subscriptions/timers for the guest** — the only lifecycle hook is
  `init-extension`.
- Ext→host: WIT imports during an export (`get-settings`, `download-file`,
  `set-language-server-installation-status`, http-client, process…). **Crucial hook**:
  `WasmState::on_main_thread` (wasm_host.rs:905-934) — an import hops to the main thread
  with `AsyncApp`. This is what `update-status-item`/`update-panel` would use.
- Fan-out: global `ExtensionHostProxy` (`extension_host_proxy.rs:26-35`) with 8
  registrable sub-proxies (theme :63, language :71, language_server :75,
  context_server :83, debug_adapter :87, language_model_provider :93). Registered at
  boot: `crates/zed/src/main.rs` :563/:568/:663/:673. **Pattern: add one more sub-proxy
  — it is designed for this.**
- **Design consequence**: no spontaneous guest→host push ⇒ the API must be
  **host-driven refresh** (click → export → extension returns a new tree / calls an
  import on the way back).

### e) Precedents of extension → UI (weakest to strongest)

1. Themes/icon themes (JSON → `ThemeRegistry`).
2. **LSP status → `ActivityIndicator` in the status bar** (import :1044 → proxy :326-336)
   — *an extension already pushes state into the status bar today*, with a fixed
   vocabulary.
3. Slash commands (return `SlashCommandOutput`; no consumer today — assistant1 vestige).
4. Debug adapters (JSON-schema feeds the debugger UI).
5. **Context servers (MCP) — the strongest**: an export returns
   `ContextServerConfiguration { installation_instructions (markdown), default_settings,
   settings_schema (JSON Schema) }` (`crates/extension/src/types/context_server.rs:5-9`),
   rendered as a GPUI modal (`agent_ui/src/context_server_configuration.rs:79-116`).
   **Extension-provided markdown + form already become GPUI today.**
6. Agent servers (`[agent_servers]` → `agent_server_store.rs` → `agent_registry_ui.rs`).

### f) Panel and status bar registration (wiring targets)

- `Panel` trait: `crates/workspace/src/dock.rs:36-96`. **Structural obstacle #1**:
  `persistent_name()`/`panel_key()` are **associated functions without `&self`**
  (identity by *type*, dock.rs:37-38) and `add_panel` is generic over the type
  (workspace.rs:2532-2567) → N dynamic panels have no identity/persistence of their own.
- Native panels are added in `crates/zed/src/zed.rs`: `initialize_panels` :752-789;
  agent panel via `setup_or_teardown_ai_panel` :791-825 → `workspace.add_panel` at
  **zed.rs:815**.
- Status bar: `StatusItemView: Render` trait (`status_bar.rs:42-59`; implement the new
  `hide_setting`/`HideStatusItem` :23-40 from the start — the file was recently
  reworked). Insertion `add_left_item`/`add_right_item`/`insert_item_after`
  :316/:381/:351. Native items created in zed.rs **:611-627**. StatusBar is per-window →
  extension state lives in a global store observed by a per-window item.

### g) Reusable declarative infrastructure

- **agent_ui/ACP is a JSON→GPUI renderer in production**: `acp_thread.rs` (`ToolCall`
  :851-870, `Plan` :1942) rendered by `thread_view.rs` (`render_tool_call` :8090,
  `MarkdownElement` :3655). The exact mental model for the extension "ui-tree JSON".
- Ready-made components in `crates/ui/src/components/`: `data_table/`, `list/`,
  `tree_view_item.rs`, `button/`, `progress/`, `context_menu.rs`, `popover.rs` etc.
- `markdown` crate (`MarkdownElement`) → rich text for free.

---

## 5. Verdict and patch plan (series 0010+)

**FEASIBLE.** The code has ~80% of the plumbing (pluggable sub-proxy, `on_main_thread`,
double-keyed capabilities, context-server precedent). Direction: **declarative,
host-driven, capability-gated** — aligned with #37270 and with the Zed team's own likely
future design (if upstream tackles the RFC, our patches become an upstreaming prototype,
not a dead end).

### Phase 1 — plumbing + status bar item (~600-900 lines, LOW risk)

| # | Change | Where | Size |
|---|---|---|---|
| 1 | WIT `since_v0.9.9/` (0.8.0 copy + `status-item.wit`: record `{icon,label,tooltip,color?}`, import `update-status-item(id,item)`, export `status-item-clicked(id)`) | `crates/extension_api/wit/` | ~150 + mechanical copy |
| 2 | Host `since_v0_9_9.rs` + dispatch arm (wit.rs:94-130) + MAX_VERSION bump + Stable gate (wit.rs:66) | `extension_host/wasm_host/wit*` | ~300 (mirror) |
| 3 | `status_items` in the manifest | `extension_manifest.rs` ~:108-118 | ~20 |
| 4 | `ExtensionStatusItemProxy` | `extension_host_proxy.rs` | ~60 |
| 5 | **New crate** `status_item_extension` (global store + `StatusItemView` w/ `hide_setting`) | new crate | ~250 |
| 6 | Import impl via `on_main_thread` | `since_v0_9_9.rs` | ~60 |
| 7 | Wiring: `main.rs` ~:663 + zed.rs :611-627 | 2 hunks | ~10 |

### Phase 2 — read-only declarative panel (~1.5-2.5k lines, MEDIUM risk)

- `[panels.<id>]` in the manifest (title, `IconName`, default dock).
- UI JSON schema (tree/table/markdown/rows/buttons→`action-id`) + **new crate**
  `extension_panel_ui` (renderer using `tree_view_item`/`data_table`/`button` +
  `MarkdownElement`, ~500-1000 lines).
- Exports `panel-root(panel-id) -> ui-json`, `panel-action(panel-id, action-id)`;
  import `update-panel(panel-id, ui-json)`.
- **MVP: a single "Extension Panel" container** (sidesteps the `Panel` trait's static
  identity — zero patches to dock.rs, no per-extension position persistence).
- Registered in zed.rs `initialize_panels` :777-785 (~5 lines).

### Phase 3 (optional)

Per-instance identity in the dock (~50 lines in dock.rs + serialization — medium risk),
text-input, incremental refresh.

### Cross-cutting risks

1. WIT version gate on the Stable channel (wit.rs:60-70) — 1-line patch.
2. No spontaneous guest→host push — host-driven API by design.
3. Upstream creating its own 0.9.0 (PENDING_CHANGES.md) — mitigated by `0.9.9`.
4. `status_bar.rs` recently reworked (`HideStatusItem`) — implement from the start.

### Maintenance cost (yardstick from the current flow)

Current series: **~3,000 lines** (0001 27L/1 file; 0002 1,696L/13 files; 0005 64L;
0006 660L/3; 0007 326L/2; 0008 113L; 0009 199L), survives **daily bumps**. Phases 1+2
add ~2-3k lines with a **better** rebase profile than 0002: new WIT dirs + new crates =
append-only (conflict ~zero); contact with hot code = tiny hunks in stable regions.

---

## 6. Didactics: the three paths (A/B/C)

Analogy: Zed is a **house** built by Zed Industries.

- **B — native patch in the fork** = *you are the builder with the blueprints*. You
  change the source (Rust/GPUI) and recompile. **Unlimited** power (move/redesign the
  screen, brand-new Agent Panel from scratch). Price: rebase on every update. **It is
  what we already do** (0001-0009; e.g. 0007 badge, 0008 attachments). Exists only in
  the overlay build.
- **A — declarative API (series 0010+)** = *installing standardized wall sockets*.
  WASM extensions (guests) plug UI into fixed slots (status bar, dock panel) describing
  **what** to show as data; Zed draws it with native finish (automatic theming). No Zed
  recompile per extension change. Limited vocabulary.
- **C — standalone GPUI app** = GPUI as a crate in your own app, outside Zed.

**A is built using B** (the patches create the sockets). Rule of thumb:
*want to change Zed → B; want an extension to show things in Zed → A.*

Direct answers given to the user:
- Redesign the screen / move Zed elements → **B only** (A does not reshape chrome).
- A completely new Agent Panel → **B** (own crate + `workspace.add_panel` at zed.rs:815;
  feasible, large patch; A is not enough — vocabulary too poor for streaming chat).
- Beautiful interfaces like GPUI apps → **B** has the same visual ceiling as those apps
  (including using the `gpui-component` lib); **A** stays limited to the defined
  vocabulary.

Verified GPUI apps ([awesome-gpui](https://github.com/zed-industries/awesome-gpui)):
[Hummingbird](https://github.com/hummingbird-player/hummingbird) (music player),
[Futureboard](https://github.com/futureboard/Futureboard) (DAW),
[Fulgur](https://github.com/fulgur-app/Fulgur) (editor). Useful libs: `gpui-component`
(charts/dock/tables), `declarative-gpui`, `gpui-router`, `gpui-video-player`.

---

## 7. Workspace state and next step

- **Overlay**: `/home/otaku/Projetos/git/bentoo/app-editors/zed/` — ebuild
  `zed-1.12.0_pre20260710-r1.ebuild`, patches in `files/` (0001, 0002, 0005-0009).
- That workspace (`claude-agent-fork`) is the ACP adapter (fork/ + claude-agent-acp-plus/);
  the Zed patches live in the bentoo overlay, not there.
- **Next step agreed as a suggestion** (not yet authorized/started at the time):
  formalize as a `.epic` story — design of `status-item.wit`, the panel JSON schema, an
  example extension for acceptance, then implement Phase 1 as patches 0010+ in the
  overlay. *(Superseded: the Zeo fork project absorbed this plan — see
  [ROADMAP.md](ROADMAP.md), stories 004-005.)*
- Flow reminders: `.epic/` never committed (gitignored); no casual pushes in `fork/`
  (the remote is the third-party upstream); adapter changes land in fork/ **and** plus/.
