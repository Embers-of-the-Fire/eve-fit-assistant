# efa-chat: AI Chat Feature

Multi-provider chat assistant feature spanning three layers: the `efa-chat` Rust crate, the
FRB bridge in `rust/src/api/chat.rs`, and the Dart feature in `lib/features/chat/`.

## Rust crate (`rust/lib/efa-chat/`)

A standalone workspace crate (member of the root `Cargo.toml`), independent of the fitting
engine. Built on `rig` (0.41). Three providers are supported via enum dispatch (rig's
dynamic-model-creation pattern): OpenAI-compatible (any Chat Completions endpoint),
Anthropic, and DeepSeek.

| File | Contents |
| ------ | ---------- |
| `src/lib.rs` | Module exports, re-exports `rig::message::Message`, and `runtime()` — a lazily-initialized shared multi-thread tokio runtime (2 worker threads). All async work runs on this runtime, never on FRB's executor. |
| `src/config.rs` | `ChatProviderKind` (`OpenAiCompatible`/`Anthropic`/`DeepSeek`, each with a default base URL); `ChatProviderConfig` (provider / api_key / base_url / model / system_prompt / max_turns) with eager validation. A blank `base_url` resolves to the provider default (`resolved_base_url`); `with_system_prompt` overrides the prompt (blank keeps the default); `max_turns` is the multi-turn depth (tool-call roundtrips per turn, `DEFAULT_MAX_TURNS` = 20, `with_max_turns` overrides, 0 ignored). |
| `src/agent.rs` | `ChatAgent` — stores the config plus a `Vec<Message>` history and builds a fresh provider agent per turn (`TurnAgent` enum over `Agent<openai::CompletionModel>` / `Agent<anthropic::…>` / `Agent<deepseek::…>`; each arm attaches the manual tools when a corpus is set). `chat_turn` is a one-shot completion; `stream_turn` drives each provider's multi-turn stream through the generic `drive_stream` helper and reports via `FnMut(ChatEvent)`. |
| `src/manual.rs` | In-memory manual corpus + rig `PortableTool`s. `ManualCorpus` groups `ManualDocText` localizations by path-joined doc id (`from_rows`); `search(keywords, language, limit)` does case-insensitive substring matching (zh-safe) ranked by distinct-keyword count then title>summary>body field weight, with a char-window snippet; `get(id, language)` returns the full body. Locale resolution mirrors Dart's `resolveLocalizedKey` (exact → language prefix → `en` → first); `language: None` searches all locales. Tools: `search_manual` (`{keywords[], language?, limit?}` → hits with `id`/`url`/`snippet`/`matched_keywords`) and `get_manual_doc` (`{id, language?}` → full content); hit `url` is `efa://manual/<doc-id>`, which the in-app router already resolves. |
| `src/models.rs` | `list_models(provider, api_key, base_url)` — thin wrapper over rig's native `ModelListingClient` per provider (auth headers and pagination handled by rig); results sorted and deduped by id. Note: OpenAI-compatible listing goes through `openai::Client` (the Responses-ext client), because rig's `OpenAIModelLister` is bound to that client type. |
| `src/event.rs` | `ChatEvent::{TextDelta, Done, Error}`. |
| `src/error.rs` | `ChatError` (thiserror): `InvalidConfig`, `Client`, `Completion`, `Stream`, `ModelListing`. |

Behavioral notes:

- `stream_turn` clones the history for the stream and only appends the user prompt + accumulated
  assistant reply to `self.history` on success; a failed turn leaves history untouched.
- `set_model` keeps history (model is just a field; a fresh `Agent` is built per turn).
- The system prompt is baked in per-turn via `Agent::preamble`, not stored in history. The
  Dart side composes it (base prompt + in-app link manifest) and passes it through
  `ChatConfig.system_prompt`; the bridge forwards it via `with_system_prompt`.

## FRB bridge (`rust/src/api/chat.rs`)

Exposes the crate to Dart. Follows the FRB threading rules from AGENTS.md:

- `ChatSession` holds `Mutex<ChatAgent>`; poisoning is recovered via `into_inner`.
- `ChatConfig.provider` (`ChatProvider` enum) selects the rig provider; blank `base_url`
  means the provider default. `create`, `set_model`, `restore_history`, `clear_history`
  are `#[frb(sync)]` (cheap).
- `prompt` and `list_available_models` are **normal** FRB fns that `block_on` the efa-chat
  runtime on a pool thread — keeps rig/reqwest off FRB's executor.
- `stream_prompt(sink, text)` pushes `ChatStreamEvent::{TextDelta, Done, Error}` over a
  `StreamSink`. Stream errors are delivered as `Error` events, **not** a failed future, so Dart
  has a single error channel over the stream's lifetime.
- `ChatHistoryMessage` + `ChatRole` seed session history when resuming a persisted conversation.
- `ChatManualDoc` + `ChatSession::set_manual_docs` (`#[frb(sync)]`) hand the bundled manual
  corpus (flat doc×locale rows) to the agent, enabling the manual tools.

After changing these signatures run `./x generate rust`.

## Dart side

| Path | Role |
| ------ | ------ |
| `lib/features/chat/chat_controller.dart` | `ChatController` (riverpod singleton). Owns the `ChatSession`, keyed by a config fingerprint (`provider|baseUrl|model|apiKey`) — recreated only when settings change; on recreation the current conversation is re-seeded via `restoreHistory`. `send()` consumes `streamPrompt` events into a `streamingText` buffer; `retry()`/`dismissError()` use `failedText`. |
| `lib/features/chat/provider.dart` | `toNativeChatProvider` — maps the settings-layer `ChatProvider` to its FRB counterpart. |
| `lib/features/chat/api_key_store.dart` | Per-provider API keys in `flutter_secure_storage` (`ai_chat_api_key_<provider>`; the legacy provider-agnostic key migrates to OpenAI on first read). `aiChatApiKeyProvider` tracks the *active* provider's key. |
| `lib/features/chat/system_prompt.dart` | `chatSystemPromptProvider` — section-composed system prompt (persona + manual-tools usage + in-app link manifest) shared by chat sessions and the settings connection test. The manifest is rendered (`render/prompt_renderer.dart`) from `linkSurfaceProvider`, which derives the linkable surface from `routeCollectionProvider` (overridden in `main.dart` with the real router's collection). Routes opt in via `DeepLinkMeta` annotations in `router.dart`. Assistant bubbles route link taps through `appLinkHandlerProvider`, which validates paths against the router before pushing. |
| `lib/features/chat/manual_corpus.dart` | `chatManualCorpusProvider` — flattens the bundled manual (`manualTreeProvider` + `ManualRepository.loadContent`) into doc×locale `ChatManualDoc` rows covering **all** bundled locales; `ChatController` pushes them into each new session via `setManualDocs` (failures leave the session usable, just without the tools). |
| `lib/features/chat/model_list.dart` | `refreshAvailableModels()` fetches the active provider's model list with a shared 30 s cooldown across entry points; persists results into that provider's connection and auto-selects the first model if none chosen. |
| `lib/storage/chat/` | `ChatConversation`/`ChatMessage` freezed models + `ChatStorageService` — per-conversation JSON files via `createUserDocStore(UserDataDomain.chat)`, serialized writes through a `_pendingSync` chain, sorted by `updatedAt` desc. |
| `lib/storage/setting/setting.dart` | `AiChatSetting` — `{provider, connections: Map<ChatProvider, AiChatConnection>}`; each provider keeps its own `{baseUrl, model, models}` (blank baseUrl/model resolve to provider defaults via getters, so `s.aiChat.baseUrl`/`.model`/`.models` keep working). Legacy flat `{baseUrl, model, models}` JSON migrates into the OpenAI-compatible connection in `fromJson`; unknown provider keys are skipped. |
| `lib/pages/chat/` | Chat page + history page; `lib/pages/setting/ai-chat/` holds provider settings. |

## Commands

- Crate tests: `cargo test -p efa-chat` (unit tests cover config validation/default-URL
  resolution, per-provider agent construction, history ops, manual corpus search/get; no
  network).
- Dart tests: `dart test test/storage/chat/ test/features/chat/ test/storage/setting/`.
- After FRB API changes: `./x generate rust` then `./x lint`.
