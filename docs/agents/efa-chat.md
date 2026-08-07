# efa-chat: AI Chat Feature

OpenAI-compatible chat assistant feature spanning three layers: the `efa-chat` Rust crate, the
FRB bridge in `rust/src/api/chat.rs`, and the Dart feature in `lib/features/chat/`.

## Rust crate (`rust/lib/efa-chat/`)

A standalone workspace crate (member of the root `Cargo.toml`), independent of the fitting
engine. Built on `rig` (0.41) against any OpenAI-compatible endpoint.

| File | Contents |
| ------ | ---------- |
| `src/lib.rs` | Module exports, re-exports `rig::message::Message`, and `runtime()` — a lazily-initialized shared multi-thread tokio runtime (2 worker threads). All async work runs on this runtime, never on FRB's executor. |
| `src/config.rs` | `ChatProviderConfig` (api_key / base_url / model / system_prompt) with eager validation; `with_system_prompt` overrides the prompt (blank keeps the default); `DEFAULT_BASE_URL` (`https://api.openai.com/v1`); `DEFAULT_SYSTEM_PROMPT`. |
| `src/agent.rs` | `ChatAgent` — wraps an `openai::CompletionsClient` plus a `Vec<Message>` history. `chat_turn` is a one-shot completion; `stream_turn` streams via rig's multi-turn stream and reports through a `FnMut(ChatEvent)` callback. |
| `src/models.rs` | `list_models()` — `GET {base_url}/models` via rig's raw request API (so the auth header is applied) but **lenient deserialization**: only `id` is required. rig's builtin lister demands `created`/`owned_by` on every entry, which DeepSeek/Moonshot/vLLM omit. Results are sorted and deduped by id. |
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
- `create`, `set_model`, `restore_history`, `clear_history` are `#[frb(sync)]` (cheap).
- `prompt` and `list_available_models` are **normal** FRB fns that `block_on` the efa-chat
  runtime on a pool thread — keeps rig/reqwest off FRB's executor.
- `stream_prompt(sink, text)` pushes `ChatStreamEvent::{TextDelta, Done, Error}` over a
  `StreamSink`. Stream errors are delivered as `Error` events, **not** a failed future, so Dart
  has a single error channel over the stream's lifetime.
- `ChatHistoryMessage` + `ChatRole` seed session history when resuming a persisted conversation.

After changing these signatures run `./x generate rust`.

## Dart side

| Path | Role |
| ------ | ------ |
| `lib/features/chat/chat_controller.dart` | `ChatController` (riverpod singleton). Owns the `ChatSession`, keyed by a config fingerprint (`baseUrl|model|apiKey`) — recreated only when settings change; on recreation the current conversation is re-seeded via `restoreHistory`. `send()` consumes `streamPrompt` events into a `streamingText` buffer; `retry()`/`dismissError()` use `failedText`. |
| `lib/features/chat/api_key_store.dart` | API key in `flutter_secure_storage` (never in settings JSON). |
| `lib/features/chat/system_prompt.dart` | `chatSystemPromptProvider` — section-composed system prompt (persona + in-app link manifest) shared by chat sessions and the settings connection test. The manifest is rendered (`render/prompt_renderer.dart`) from `linkSurfaceProvider`, which derives the linkable surface from `routeCollectionProvider` (overridden in `main.dart` with the real router's collection). Routes opt in via `DeepLinkMeta` annotations in `router.dart`. Assistant bubbles route link taps through `appLinkHandlerProvider`, which validates paths against the router before pushing. |
| `lib/features/chat/model_list.dart` | `refreshAvailableModels()` fetches the provider model list with a shared 30 s cooldown across entry points; persists results into settings and auto-selects the first model if none chosen. |
| `lib/storage/chat/` | `ChatConversation`/`ChatMessage` freezed models + `ChatStorageService` — per-conversation JSON files via `createUserDocStore(UserDataDomain.chat)`, serialized writes through a `_pendingSync` chain, sorted by `updatedAt` desc. |
| `lib/storage/setting/setting.dart` | `AiChatSetting` (baseUrl, model, cached model list with custom JsonConverter). |
| `lib/pages/chat/` | Chat page + history page; `lib/pages/setting/ai-chat/` holds provider settings. |

## Commands

- Crate tests: `cargo test -p efa-chat` (unit tests cover config validation, history ops, lenient
  model-list parsing; no network).
- Dart tests: `dart test test/storage/chat/ test/features/chat/`.
- After FRB API changes: `./x generate rust` then `./x lint`.
