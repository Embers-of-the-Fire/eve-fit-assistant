# efa-chat: AI Chat Feature

Multi-provider chat assistant feature spanning three layers: the `efa-chat` Rust crate, the
FRB bridge in `rust/src/api/chat.rs`, and the Dart feature in `lib/features/chat/`.

## Rust crate (`rust/lib/efa-chat/`)

A standalone workspace crate (member of the root `Cargo.toml`), independent of the fitting
engine. Built on `rig` (0.41). Three providers are supported via enum dispatch (rig's
dynamic-model-creation pattern): OpenAI-compatible (any Chat Completions endpoint),
Anthropic, and DeepSeek.

The crate is organized into three top-level modules: `core` (the agent layer),
`host` (non-agent host glue), and `tools` (the rig toolset).

### `src/core/` — the agent layer

| File | Contents |
| ------ | ---------- |
| `mod.rs` | Re-exports `config`, `agent`, `error`, `event`, `models`, `prompt`, `skill`. |
| `config.rs` | `ChatProviderKind` (`OpenAiCompatible`/`Anthropic`/`DeepSeek`, each with a default base URL and a `prompt_dir()` name: `openai`/`anthropic`/`deepseek`); `PromptLanguage` (`En`/`Zh`, `from_locale` maps any non-`zh*` tag to `En`); `ChatProviderConfig` (provider / api_key / base_url / model / language / system_prompt / max_turns / proxy) with eager validation. A blank `base_url` resolves to the provider default (`resolved_base_url`). `proxy` (`with_proxy`, blank ignored) is the desktop system-proxy URL resolved by the Dart host; `http_client()`/`build_http_client()` build a reqwest client routed through it (`None` keeps rig's default client, which already reads the standard proxy env vars; ignored on wasm, where the browser applies its own proxy). Prompts are bundled from `prompt/` at compile time (`include_str!`); `prompt_bundle()` yields the per-(provider, language) constraint/appendix fragments — `prompt/constraint/system/{lang}.prompt` (shared rules), `prompt/constraint/provider/<dir>/{lang}.prompt` and `prompt/appendix/provider/<dir>/{lang}.prompt` (per-provider, e.g. the DeepSeek DSML strict-ASCII rule plus its examples appendix). `system_prompt` holds *extra sections* appended last (`with_system_prompt`, blank ignored); `full_system_prompt(context)` delegates assembly to `prompt::render_system_prompt`; `max_turns` is the multi-turn depth (tool-call roundtrips per turn, `DEFAULT_MAX_TURNS` = 20, `with_max_turns` overrides, 0 ignored). Tool descriptions are bundled the same way under `prompt/tool/<tool-name>/{en,zh}.prompt` (one directory per rig tool, named by the tool's `NAME`) and selected by the session language via `PromptLanguage::pick`. |
| `prompt.rs` | System-prompt assembly. `render_system_prompt(config, context)` joins the sections in order: identity (`prompt/system/{lang}.prompt`), `## Capabilities` (generated bullets from the *actually attached* tools, blurbs from the `TOOL_BLURBS` table — a test pins it to every tool's `NAME` constant), `## Workflow` (conditional guidance fragments from `prompt/workflow/{fit,fit_data,manual}/{lang}.prompt`), `## Skills` (manifest, only when non-empty), `## Constraint`, `## Appendix` (only when the provider bundle ships real appendix content — empty appendix files omit the section), then the volatile `## Context` block (attached-fit name/hull) and the Dart-supplied extras last, keeping the stable prefix long for provider prompt caching. `SystemPromptContext` carries which tool groups are attached (fit engine / fit data / manual), the `SkillMeta` list, and the `ActiveFitSummary`. |
| `skill.rs` | Agent skills: reusable, progressively-disclosed instruction packs. A skill is a markdown doc with `---` frontmatter (`name`, `description`) bundled under `skills/<name>/SKILL.{en,zh}.md`; `parse_skill` parses one document, `Skill::from_raw` combines localizations (names must agree; English required as the fallback), `SkillRegistry` (`new` / `bundled` / `list` / `get`) serves the manifest for the prompt and the full body for the `load_skill` tool. Only name+description enter the system prompt; the body loads on demand. |
| `agent.rs` | `ChatAgent` — stores the config plus a `Vec<Message>` history and builds a fresh provider agent per turn (`TurnAgent` enum over `Agent<openai::CompletionModel>` / `Agent<anthropic::…>` / `Agent<deepseek::…>`; each arm attaches the manual tools when a corpus is set and `load_skill` when the skill registry is non-empty). `prompt_context()` snapshots the attachment state + skill manifest + attached-fit summary that shape the system prompt. `chat_turn` is a one-shot completion; `stream_turn` drives each provider's multi-turn stream through the generic `drive_stream` helper and reports via `FnMut(ChatEvent)`. |
| `models.rs` | `list_models(provider, api_key, base_url, proxy)` — thin wrapper over rig's native `ModelListingClient` per provider (auth headers and pagination handled by rig; `proxy` feeds `build_http_client` like the session config); results sorted and deduped by id. Note: OpenAI-compatible listing goes through `openai::Client` (the Responses-ext client), because rig's `OpenAIModelLister` is bound to that client type. |
| `event.rs` | `ChatEvent::{TextDelta, ToolCallStart, ToolCallArgsDelta, ToolCallEnd, Done, Error}`; `ToolCallEnd` carries the flattened textual tool result (text items joined, JSON items serialized, images skipped). |
| `error.rs` | `ChatError` (thiserror): `InvalidConfig`, `Client`, `Completion`, `Stream`, `ModelListing`. |

### `src/host/` — non-agent host glue

| File | Contents |
| ------ | ---------- |
| `mod.rs` | Re-exports `runtime`; the home for non-agent plumbing that bridges the crate to its host (log forwarding, host runtime wiring). |
| `runtime.rs` | `runtime()` — the lazily-initialized shared multi-thread tokio runtime (2 worker threads). All async work runs on this runtime, never on FRB's executor. Re-exported at the crate root as `efa_chat::runtime()`. |

### `src/tools/` — the rig toolset

| File | Contents |
| ------ | ---------- |
| `mod.rs` | Re-exports `manual`, `fit` and `skill`. |
| `manual.rs` | In-memory manual corpus + rig `PortableTool`s. `ManualCorpus` groups `ManualDocText` localizations by path-joined doc id (`from_rows`); `search(keywords, language, limit)` does case-insensitive substring matching (zh-safe) ranked by distinct-keyword count then title>summary>body field weight, with a char-window snippet; `get(id, language)` returns the full body. Locale resolution mirrors Dart's `resolveLocalizedKey` (exact → language prefix → `en` → first); `language: None` searches all locales. Tools: `search_manual` (`{keywords[], language?, limit?}` → hits with `id`/`url`/`snippet`/`matched_keywords`) and `get_manual_doc` (`{id, language?}` → full content); hit `url` is `efa://manual/<doc-id>`, which the in-app router already resolves. |
| `fit/mod.rs` | `FitToolContext`, `FitToolError`, and the fit summary/stat/attr/validation report structs backed by the fitting engine. |
| `fit/schema.rs` | DTOs for the fit payload pushed by the app (used by `load_fit`, `create_fit`, `apply_fit_edit`). |
| `fit/edit.rs` | Fit edit operations validated against a copy of the attached fit: module ops (`add_module`/`remove_module`/`set_module_charge`/`set_module_state`), drone ops (`add_drone`/`remove_drone`/`set_drone_state`; state is `bay`/`space`, same-type drones share a group), fighter ops (`add_fighter`/`remove_fighter`; `ability` bitmask 1/2/4/8 = attack turret/missiles/attack missile/bomb, default 0), and slot ops (`set_implant`/`remove_implant` slots 1-10, `set_booster`/`remove_booster` slots 1-3; `set_*` replaces the slot's current item). `apply_edit_ops` also returns the applied ops verbatim, which `apply_fit_edit` forwards to the app for persistence. |
| `fit/tools.rs` | The fit tool definitions (`get_current_fit`, `get_fit_stats`, `get_item`, `get_attr`, `validate_fit`, and the app-state `search_items`/`list_user_fits`/`load_fit`/`create_fit`/`apply_fit_edit`). |
| `skill.rs` | `LoadSkillTool` (`load_skill`, `{name}` → full `SkillContent`), attached only when the session's `SkillRegistry` is non-empty; `SkillToolError::NotFound` lists the available skill names and reaches the model verbatim (same `ToolExecutionError` pattern as the manual tools). |

Behavioral notes:

- `stream_turn` clones the history for the stream and only appends the user prompt + accumulated
  assistant reply to `self.history` on success; a failed turn leaves history untouched.
- `set_model` keeps history (model is just a field; a fresh `Agent` is built per turn).
- The system prompt is baked in per-turn via `Agent::preamble`, not stored in history. It is
  assembled by `prompt::render_system_prompt` from the session's `prompt_context()` (which tool
  groups are attached, the skill manifest, the attached-fit summary), so tools are only
  advertised when actually attached; Dart-supplied extra sections append last.
  `ChatConfig.language` (the app locale via `localeProvider`) selects the prompt language, and
  the same language selects the bundled tool descriptions (`prompt/tool/<tool-name>/{lang}.prompt`)
  when the per-turn agent is built — fit tools receive it through `FitToolContext::with_language`,
  manual/skill tools through their constructors.
  The Dart side passes only the dynamic in-app link manifest through `ChatConfig.system_prompt`;
  the bridge forwards it via `with_system_prompt`.
- Skills: `ChatAgent::set_skill_registry` replaces the registry (default `SkillRegistry::bundled()`,
  which ships `app-usage`, `fit-analysis`, `fit-create` and `fit-edit` in en/zh under
  `skills/<name>/SKILL.{en,zh}.md`). A non-empty registry adds the `## Skills` manifest to the
  prompt and attaches the `load_skill` tool; the model loads full skill bodies on demand
  (progressive disclosure). The skills carry the tool-chaining procedures and interpretation
  knowledge, so the system prompt's `## Workflow` fragments stay minimal routing/grounding rules.

## FRB bridge (`rust/src/api/chat.rs`)

Exposes the crate to Dart. Follows the FRB threading rules from AGENTS.md:

- `ChatSession` holds `Mutex<ChatAgent>`; poisoning is recovered via `into_inner`.
- `ChatConfig.provider` (`ChatProvider` enum) selects the rig provider; blank `base_url`
  means the provider default. `ChatConfig.proxy` is the desktop system-proxy URL resolved
  by Dart (`chatProxyUrlFor` in `lib/features/chat/provider.dart`, backed by
  `lib/features/remote_content/system_proxy*.dart`: env vars first, GNOME gsettings
  fallback on Linux); `list_available_models` takes the same value. `create`, `set_model`,
  `restore_history`, `clear_history` are `#[frb(sync)]` (cheap).
- `prompt` and `list_available_models` are **async** FRB fns driven through the `drive_turn`
  helper: on native the turn future is spawned onto the efa-chat tokio runtime (keeping
  rig/reqwest off FRB's executor without blocking it); on wasm32 it is awaited directly —
  FRB runs async fns on the browser event loop, where reqwest's fetch-based futures resolve
  (`block_on` on wasm would deadlock the worker event loop).
- `stream_prompt(sink, text)` (also async, same `drive_turn` split) pushes
  `ChatStreamEvent::{TextDelta, ToolCallStart, ToolCallArgsDelta, ToolCallEnd, Done, Error}`
  over a `StreamSink`. Stream errors are delivered as `Error` events, **not** a failed future,
  so Dart has a single error channel over the stream's lifetime.
- `ChatHistoryMessage` + `ChatRole` seed session history when resuming a persisted conversation.
- `ChatManualDoc` + `ChatSession::set_manual_docs` (`#[frb(sync)]`) hand the bundled manual
  corpus (flat doc×locale rows) to the agent, enabling the manual tools.
- `ChatSession::open_callback_channel` + `deliver_callback_result` back the app-state tools
  (`search_items`/`list_user_fits`/`load_fit`/`create_fit`/`apply_fit_edit`). FRB Dart closures
  (DartFn) are **not** used:
  their invoke message crosses a `BroadcastChannel` as a raw `JSValue` that FRB's Dart port
  manager cannot decode on dart2wasm (only dart2js auto-converts), crashing the port listener.
  The bridge therefore runs its own request/response channel: a `StreamSink` pushes
  `ChatCallbackRequest::{SearchItems, ListFits, LoadFit, CreateFit, ApplyFitEdit}` (each with a
  `call_id`) to Dart, and
  the async `deliver_callback_result(call_id, result)` completes the oneshot the tool future
  awaits (async so the wake happens on the browser event loop on web). `search_items` receives
  `(query, language?, kind?)`, where `language` selects the name localization to search
  (omitted → app display language) and `kind` optionally restricts results to one item kind
  (`ship`/`module`/`charge`/`drone`/`fighter`/`implant`/`booster`). The kind filter is applied
  inside the agent resource database query (schema v2 `type_names` columns `group_id`/
  `category_id`/`slot_index`/`slot_kind`); implant and booster hits carry `slot_index` for
  `apply_fit_edit`'s `set_implant`/`set_booster`.

Fit mutation tools:

- `create_fit(ship_id, name, description?)` asks the app to save a new fit
  (`FitManager.newFit`), attaches it (like `load_fit`), and returns its summary.
- `apply_fit_edit(edits)` validates the ops against a copy of the attached fit
  (`apply_edit_ops`), then forwards the *applied* ops verbatim to the app's
  `ApplyFitEdit` callback, which translates them onto the stored `FitStorage`
  (`lib/features/chat/fit_edit_apply.dart`) and persists through `Fit.update`; the returned
  `FitPayload` replaces the attached fit so subsequent tool calls in the same turn see the new
  state. App `{"error": ...}` envelopes (e.g. read-only incompatible checkout) surface as
  tool errors. There is no confirmation step by design.

After changing these signatures run `./x generate rust`.

## Dart side

| Path | Role |
| ------ | ------ |
| `lib/features/chat/chat_controller.dart` | `ChatController` (riverpod singleton). Owns the `ChatSession`, keyed by a config fingerprint (`provider|baseUrl|model|apiKey`) — recreated only when settings change; on recreation the current conversation is re-seeded via `restoreHistory`. `send()` consumes `streamPrompt` events into a `streamingText` buffer; `retry()`/`dismissError()` use `failedText`. |
| `lib/features/chat/provider.dart` | `toNativeChatProvider` — maps the settings-layer `ChatProvider` to its FRB counterpart. |
| `lib/features/chat/api_key_store.dart` | Per-provider API keys in `flutter_secure_storage` (`ai_chat_api_key_<provider>`; the legacy provider-agnostic key migrates to OpenAI on first read). `aiChatApiKeyProvider` tracks the *active* provider's key. |
| `lib/features/chat/system_prompt.dart` | `chatSystemPromptProvider` — extra system-prompt sections (the in-app link manifest; the persona + manual-tools base is bundled in the efa-chat crate under `prompt/`) shared by chat sessions and the settings connection test. The manifest is rendered (`lib/features/deeplink/render/prompt_renderer.dart`) from `linkSurfaceProvider`, which derives the linkable surface from `routeCollectionProvider` (overridden in `main.dart` with the real router's collection). Routes opt in via `DeepLinkMeta` annotations in `router.dart`. Assistant bubbles route link taps through `appLinkHandlerProvider`, which validates paths against the router before pushing. |
| `lib/features/chat/manual_corpus.dart` | `chatManualCorpusProvider` — flattens the bundled manual (`manualTreeProvider` + `ManualRepository.loadContent`) into doc×locale `ChatManualDoc` rows covering **all** bundled locales; `ChatController` pushes them into each new session via `setManualDocs` (failures leave the session usable, just without the tools). |
| `lib/features/chat/fit_context.dart` | Fit-context wiring: attaches the engine, attribute names, and the fit page's currently open fit (`pushAttachedFit`), and registers the app-state tool callbacks by listening on `openCallbackChannel()` and answering each request with `deliverCallbackResult()`. The `search_items` callback resolves the model-supplied `language` tag to a localization-db locale (zh*→zh, anything else→en; omitted/blank→app display locale). The `create_fit` callback goes through `FitManager.newFit` (shipId + name + optional description) and attaches the new fit; the `apply_fit_edit` callback decodes the ops JSON, applies it via `fit_edit_apply.dart` onto the attached fit's `FitStorage` through `Fit.update` (holding the auto-dispose `fitProvider` alive with `ref.listen` across the update), and returns the updated `FitPayload`. |
| `lib/features/chat/fit_edit_apply.dart` | Pure translator from chat edit ops (JSON) onto the storage-layer `FitStorage` model: fixed module slot lists (first-free index), quantity-based drone/fighter groups, implant slots resolved through bundle metadata (`collection.slots.implantSlots`), booster slots by stored index. Unapplicable ops are skipped (the chat crate already validated them). |
| `lib/features/chat/model_list.dart` | `refreshAvailableModels()` fetches the active provider's model list with a shared 30 s cooldown across entry points; persists results into that provider's connection and auto-selects the first model if none chosen. |
| `lib/storage/chat/` | `ChatConversation`/`ChatMessage` freezed models + `ChatStorageService` — per-conversation JSON files via `createUserDocStore(UserDataDomain.chat)`, serialized writes through a `_pendingSync` chain, sorted by `updatedAt` desc. |
| `lib/storage/setting/setting.dart` | `AiChatSetting` — `{provider, connections: Map<ChatProvider, AiChatConnection>}`; each provider keeps its own `{baseUrl, model, models}` (blank baseUrl/model resolve to provider defaults via getters, so `s.aiChat.baseUrl`/`.model`/`.models` keep working). Legacy flat `{baseUrl, model, models}` JSON migrates into the OpenAI-compatible connection in `fromJson`; unknown provider keys are skipped. |
| `lib/pages/chat/` | Chat page + history page; `lib/pages/ai/` holds provider settings. |

## Commands

- Crate tests: `cargo test -p efa-chat` (unit tests cover config validation/default-URL
  resolution, per-provider agent construction, history ops, manual corpus search/get; no
  network).
- Dart tests: `dart test test/storage/chat/ test/features/chat/ test/storage/setting/`.
- After FRB API changes: `./x generate rust` then `./x lint`.
