# ZEO.md — Visual Extension API para o Zed (handoff de sessão)

> Contexto completo da conversa de 2026-07-10 sobre criar, via patches próprios, uma API de UI
> para extensões do Zed. Documento de continuação para nova sessão.

---

## 1. Pergunta original e contexto

O usuário perguntou se é possível editar a UI do Agent Panel / do editor Zed, como funciona o
**GPUI** e se usa JavaScript. Depois, se o VSCode tem uma "API de UI", se existe iniciativa
disso no Zed, e por fim decidiu: **"vamos criar nós mesmos nossos patches para suportar isso"**.

### Fatos base estabelecidos

- **GPUI** = framework de UI da Zed Industries, Rust puro, renderização 100% GPU
  (Metal/macOS, **Vulkan via `blade`/Linux**, DirectX/Windows). Zero JavaScript/HTML/Electron.
  Modelo declarativo (views com trait `Render`, API fluente estilo Tailwind, `Entity<T>` +
  contextos), híbrido immediate/retained. Glifos rasterizados em atlas; resto vira quads/paths.
- **Zed hoje não tem API de UI para extensões**: extensões são WASM (wasmtime) limitadas a
  linguagens, temas, slash commands, context servers (MCP), debug adapters, agent servers.
  Nenhum acesso a GPUI/janela/painéis.
- **VSCode** (comparação): contribution points declarativos + **webviews** (iframe sandboxed
  com HTML/JS livre — é assim que o painel do Claude Code funciona lá). O chrome do workbench
  é trancado de propósito. No Zed via ACP, a UI é nativa (GPUI) e o adapter só fala protocolo —
  daí a série de patches deste workspace para fechar gaps de UI.

### Código relevante do Zed (UI)

- Agent Panel: `crates/agent_ui/` (`agent_panel.rs`, `message_editor.rs`, `acp/thread_view.rs`)
- Editor/workspace: `crates/editor/`, `crates/workspace/`, componentes em `crates/ui/`

---

## 2. Pesquisa: iniciativas existentes (GitHub)

**Nenhum PR existe. Só discussões. Posição oficial: "no radar, mas não no futuro próximo".**

| Item | O quê | Status |
|---|---|---|
| [RFC #53403 — Visual Extension API](https://github.com/zed-industries/zed/discussions/53403) (abr/2026, ~40+ upvotes) | Propõe WIT para painéis, status bar items e views via GPUI (não webview). Pseudocódigo detalhado (ver §3) | Mantenedor **macraig** (mai/2026): *"needs to be driven by our team… significant undertaking, not something we're likely to get to in the near future"* |
| [#48015 — UI modifications via extensions using GPUI](https://github.com/zed-industries/zed/discussions/48015) (jan/2026) | Botões status bar, painéis, tabelas/grids nativos | Aberta, sem resposta de mantenedor |
| [#37270 — custom rendering of documents](https://github.com/zed-industries/zed/discussions/37270) | **A mais importante tecnicamente**: reconhece que WASM tem zero acesso a GPUI; caminho realista = **protocolo declarativo** (extensão descreve UI como dados, Zed renderiza nativo) | Discussão |
| [#17325 — Custom Views in Extension API](https://github.com/zed-industries/zed/issues/17325) (set/2024) | Views customizadas via GPUI | Fechada `state:unactionable` |
| [#6679 — GPUI2 and extensions](https://github.com/zed-industries/zed/discussions/6679) | Discussão histórica (era GPUI2) | Antiga |

Extensibilidade recente do Zed foi em outras frentes (debug adapters, context servers/MCP,
agent servers/ACP, icon themes) — nunca UI. Comunidade frustrada com priorização de AI.

---

## 3. Desenho do RFC #53403 (referência de API)

```wit
// Painéis
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

- Element tree variant-based: container, text, button, text-input, table, list, icon.
- Fases propostas: **1** status bar (1-2 sem) → **2** painéis read-only (3-4 sem) →
  **3** interativo (6-8 sem) → **4** rendering avançado (2-3 meses).
- Segurança: WASM sandbox mantido, componentes pré-definidos (sem HTML/CSS arbitrário),
  frame budget com auto-disable, limites de tamanho/contagem.
- Objeção no thread (nakajimayoshi): expor GPUI direto via trait Rust — **descartada** na
  nossa análise (inviável no sandbox WASM, inseguro). Direção certa = declarativa (#37270),
  mesmo princípio do ACP.

---

## 4. Mapeamento do código real do Zed (subagente, clone @ `5f8a7413a31769`, 2026-07-10)

> O clone sparse ficou em scratchpad de sessão (efêmero). Para recriar:
> `git clone --filter=blob:none --sparse --depth 1 https://github.com/zed-industries/zed`
> `git sparse-checkout set crates/extension_api crates/extension crates/extension_host crates/agent_ui/src crates/workspace/src crates/zed/src`

### a) Runtime de extensões

- **wasmtime (component model) + WASI**, in-process. Host: `crates/extension_host/src/wasm_host.rs`
  (`WasmHost` :48-60; engine com `epoch_interruption(true)` + thread de epoch :546-585;
  yield cooperativo por tick — UI nunca bloqueia :660-675).
- Carga: `load_extension` :633-727 — lê versão da API da custom section `zed:api-version`
  (guest grava em `crates/extension_api/src/extension_api.rs:351-353`; parse
  `crates/extension/src/extension.rs:184`), chama `init-extension` :687, roda **loop de
  mensagens** por extensão (mpsc de closures `ExtensionCall` :691-696).
- Sandbox FS: WASI só com work-dir da extensão preaberto (:729-751).
- Orquestração: `ExtensionStore` (`extension_host.rs:129`, init :265); registro pós-load
  :1531-1573 (LSP :1538, context servers :1548, debug adapters :1561), evento
  `ExtensionsInstalledChanged` :1580-1584.

### b) WIT versionado (chave para o patch)

- Guest: `crates/extension_api/wit/since_v{0.0.1 … 0.8.0}/` — dirs **imutáveis por versão**.
  A 0.8.0 tem: extension.wit, common.wit, context-server.wit, dap.wit, github.wit,
  http-client.wit, lsp.wit, nodejs.wit, platform.wit, process.wit, slash-command.wit.
- Host espelhado: `crates/extension_host/src/wasm_host/wit/since_v0_x_y.rs` (10 módulos),
  dispatch enum `Extension` (wit.rs:94-104), cascata `instantiate_async` (wit.rs:118-205).
- **Gate de canal**: `wasm_api_version_range` (wit.rs:60-70) — Stable/Preview aceitam no máx.
  `0.7.0`; a 0.8.0 só Dev/Nightly (since_v0_8_0.rs:33-34). **Patch precisa de 1 linha em
  wit.rs:66** (ou rodar dev/nightly).
- **Upstream tem breaking changes pendentes** em `crates/extension_api/PENDING_CHANGES.md`
  para a próxima versão → **usar `since_v0.9.9/` no fork** para evitar colisão com a 0.9.0 deles.

### c) Capabilities

- `ExtensionManifest.capabilities` (`extension_manifest.rs:114`); enum em
  `crates/extension/src/capabilities.rs:14-20` (`process:exec`, `download_file`, `npm:install`).
- Dupla checagem: manifesto declara **e** usuário concede via settings
  (`granted_capabilities`, `extension_settings.rs:18,43-58` → wasm_host.rs:627), aplicado por
  `CapabilityGranter` (`capability_granter.rs:23-48`). **`ui:status_item`/`ui:panel` encaixam
  nesse molde sem mudança estrutural.**

### d) Comunicação host↔extensão

- Host→ext: só exports WIT sob demanda via `WasmExtension::call` (wasm_host.rs:872-901).
  **Não há eventos/subscriptions/timers para o guest** — único lifecycle é `init-extension`.
- Ext→host: imports WIT durante um export (`get-settings`, `download-file`,
  `set-language-server-installation-status`, http-client, process…). **Gancho crucial**:
  `WasmState::on_main_thread` (wasm_host.rs:905-934) — import salta para main thread com
  `AsyncApp`. É o que `update-status-item`/`update-panel` usariam.
- Fan-out: `ExtensionHostProxy` global (`extension_host_proxy.rs:26-35`) com 8 sub-proxies
  registráveis (theme :63, language :71, language_server :75, context_server :83,
  debug_adapter :87, language_model_provider :93). Registro no boot: `crates/zed/src/main.rs`
  :563/:568/:663/:673. **Padrão: adicionar mais um sub-proxy — é desenhado para isso.**
- **Consequência de design**: sem push espontâneo guest→host ⇒ API deve ser **host-driven
  refresh** (clique → export → extensão devolve árvore nova / chama import no retorno).

### e) Precedentes de extensão → UI (do mais fraco ao mais forte)

1. Temas/icon themes (JSON → `ThemeRegistry`).
2. **Status de LSP → `ActivityIndicator` na status bar** (import :1044 → proxy :326-336) —
   *já existe extensão empurrando estado para a status bar*, com vocabulário fixo.
3. Slash commands (retornam `SlashCommandOutput`; hoje sem consumidor — vestígio assistant1).
4. Debug adapters (JSON-schema alimenta UI do debugger).
5. **Context servers (MCP) — o mais forte**: export retorna
   `ContextServerConfiguration { installation_instructions (markdown), default_settings,
   settings_schema (JSON Schema) }` (`crates/extension/src/types/context_server.rs:5-9`),
   renderizado como modal GPUI (`agent_ui/src/context_server_configuration.rs:79-116`).
   **Markdown + formulário de extensão já viram GPUI hoje.**
6. Agent servers (`[agent_servers]` → `agent_server_store.rs` → `agent_registry_ui.rs`).

### f) Registro de painéis e status bar (alvos do wiring)

- Trait `Panel`: `crates/workspace/src/dock.rs:36-96`. **Obstáculo estrutural nº 1**:
  `persistent_name()`/`panel_key()` são **funções associadas sem `&self`** (identidade por
  *tipo*, dock.rs:37-38) e `add_panel` é genérico por tipo (workspace.rs:2532-2567) →
  N painéis dinâmicos não têm identidade/persistência própria.
- Painéis nativos adicionados em `crates/zed/src/zed.rs`: `initialize_panels` :752-789;
  agent panel via `setup_or_teardown_ai_panel` :791-825 → `workspace.add_panel` em **zed.rs:815**.
- Status bar: trait `StatusItemView: Render` (`status_bar.rs:42-59`; implementar o novo
  `hide_setting`/`HideStatusItem` :23-40 desde o início — arquivo reformado recentemente).
  Inserção `add_left_item`/`add_right_item`/`insert_item_after` :316/:381/:351. Itens nativos
  criados em zed.rs **:611-627**. StatusBar é por janela → estado de extensão vive em store
  global observado por item por janela.

### g) Infra declarativa reaproveitável

- **agent_ui/ACP é um renderer JSON→GPUI em produção**: `acp_thread.rs` (`ToolCall` :851-870,
  `Plan` :1942) renderizado por `thread_view.rs` (`render_tool_call` :8090, `MarkdownElement`
  :3655). Modelo mental exato para o "ui-tree JSON" de extensão.
- Componentes prontos em `crates/ui/src/components/`: `data_table/`, `list/`,
  `tree_view_item.rs`, `button/`, `progress/`, `context_menu.rs`, `popover.rs` etc.
- Crate `markdown` (`MarkdownElement`) → texto rico de graça.

---

## 5. Veredicto e plano de patches (série 0010+)

**VIÁVEL.** O código tem ~80% da tubulação (sub-proxy plugável, `on_main_thread`, capabilities
dupla-chave, precedente context-server). Direção: **declarativa, host-driven, capability-gated**
— alinhada ao #37270 e ao provável desenho futuro do próprio time Zed (se upstream atacar o
RFC, nossos patches viram protótipo de upstreaming, não beco sem saída).

### Fase 1 — tubulação + status bar item (~600-900 linhas, risco BAIXO)

| # | Mudança | Onde | Tamanho |
|---|---|---|---|
| 1 | WIT `since_v0.9.9/` (cópia 0.8.0 + `status-item.wit`: record `{icon,label,tooltip,color?}`, import `update-status-item(id,item)`, export `status-item-clicked(id)`) | `crates/extension_api/wit/` | ~150 + cópia mecânica |
| 2 | `since_v0_9_9.rs` host + braço no dispatch (wit.rs:94-130) + bump MAX_VERSION + gate Stable (wit.rs:66) | `extension_host/wasm_host/wit*` | ~300 (espelho) |
| 3 | `status_items` no manifesto | `extension_manifest.rs` ~:108-118 | ~20 |
| 4 | `ExtensionStatusItemProxy` | `extension_host_proxy.rs` | ~60 |
| 5 | **Crate novo** `status_item_extension` (store global + `StatusItemView` c/ `hide_setting`) | crate novo | ~250 |
| 6 | Impl do import via `on_main_thread` | `since_v0_9_9.rs` | ~60 |
| 7 | Wiring: `main.rs` ~:663 + zed.rs :611-627 | 2 hunks | ~10 |

### Fase 2 — painel declarativo read-only (~1.5-2.5k linhas, risco MÉDIO)

- `[panels.<id>]` no manifesto (título, `IconName`, dock default).
- Schema JSON de UI (tree/table/markdown/rows/buttons→`action-id`) + **crate novo**
  `extension_panel_ui` (renderer usando `tree_view_item`/`data_table`/`button` +
  `MarkdownElement`, ~500-1000 linhas).
- Exports `panel-root(panel-id) -> ui-json`, `panel-action(panel-id, action-id)`;
  import `update-panel(panel-id, ui-json)`.
- **MVP: um único painel contêiner "Extension Panel"** (contorna a identidade estática do
  trait `Panel` — zero patch em dock.rs, sem persistência de posição por extensão).
- Registro em zed.rs `initialize_panels` :777-785 (~5 linhas).

### Fase 3 (opcional)

Identidade por instância no dock (~50 linhas em dock.rs + serialização — risco médio),
text-input, refresh incremental.

### Riscos transversais

1. Gate de versão WIT no canal Stable (wit.rs:60-70) — 1 linha de patch.
2. Sem push espontâneo guest→host — API host-driven por design.
3. Upstream criar a própria 0.9.0 (PENDING_CHANGES.md) — mitigado por `0.9.9`.
4. `status_bar.rs` reformado recentemente (`HideStatusItem`) — implementar desde o início.

### Custo de manutenção (régua do fluxo atual)

Série atual: **~3.000 linhas** (0001 27L/1 arq; 0002 1.696L/13 arqs; 0005 64L; 0006 660L/3;
0007 326L/2; 0008 113L; 0009 199L), sobrevive a **bumps diários**. Fases 1+2 adicionam
~2-3k linhas com perfil de rebase **melhor** que o 0002: dirs WIT novos + crates novos =
append-only (conflito ~zero); contatos com código quente = hunks minúsculos em regiões estáveis.

---

## 6. Didática: os três caminhos (A/B/C)

Analogia: o Zed é uma **casa** construída pela Zed Industries.

- **B — patch nativo no fork** = *você é o pedreiro com a planta na mão*. Altera o
  código-fonte (Rust/GPUI) e recompila. Poder **ilimitado** (mover/redesenhar tela, Agent
  Panel novo do zero). Preço: rebase a cada update. **É o que já fazemos** (0001-0009;
  ex.: 0007 badge, 0008 attachments). Só existe no build da overlay.
- **A — API declarativa (série 0010+)** = *instalar tomadas padronizadas na parede*.
  Extensões WASM (visitantes) plugam UI em slots fixos (status bar, painel no dock)
  descrevendo **o quê** mostrar como dados; o Zed desenha com acabamento nativo (theming
  automático). Sem recompilar o Zed a cada mudança da extensão. Vocabulário limitado.
- **C — app GPUI standalone** = GPUI como crate num app próprio, fora do Zed.

**A é construído usando B** (os patches criam as tomadas). Regra de bolso:
*quer mudar o Zed → B; quer que uma extensão mostre coisas no Zed → A.*

Respostas diretas dadas ao usuário:
- Redesenhar tela / mover elementos do Zed → **só B** (A não remodela chrome).
- Agent Panel completamente novo → **B** (crate próprio + `workspace.add_panel` em zed.rs:815;
  viável, patch grande; A não serve — vocabulário pobre para chat com streaming).
- Interfaces bonitas tipo apps GPUI → **B** tem o mesmo teto visual desses apps
  (inclusive usando a lib `gpui-component`); **A** fica limitado ao vocabulário definido.

Apps GPUI verificados ([awesome-gpui](https://github.com/zed-industries/awesome-gpui)):
[Hummingbird](https://github.com/hummingbird-player/hummingbird) (music player),
[Futureboard](https://github.com/futureboard/Futureboard) (DAW),
[Fulgur](https://github.com/fulgur-app/Fulgur) (editor). Libs úteis: `gpui-component`
(charts/dock/tabelas), `declarative-gpui`, `gpui-router`, `gpui-video-player`.

---

## 7. Estado do workspace e próximo passo

- **Overlay**: `/home/otaku/Projetos/git/bentoo/app-editors/zed/` — ebuild
  `zed-1.12.0_pre20260710-r1.ebuild`, patches em `files/` (0001, 0002, 0005-0009).
- Este workspace (`claude-agent-fork`) é o adapter ACP (fork/ + claude-agent-acp-plus/);
  os patches do Zed vivem na overlay bentoo, não aqui.
- **Próximo passo acordado como sugestão** (ainda não autorizado/iniciado): formalizar como
  story `.epic` — design do `status-item.wit`, schema JSON do painel, extensão de exemplo
  para aceitação, e então implementar a Fase 1 como patches 0010+ na overlay.
- Lembretes de fluxo: `.epic/` nunca commitado (gitignore); nada de push casual no `fork/`
  (remote é o upstream de terceiros); mudanças no adapter aterrissam em fork/ **e** plus/.
