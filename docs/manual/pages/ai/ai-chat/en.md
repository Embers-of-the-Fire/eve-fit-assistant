---
title: Chat
summary: Converse with the AI assistant, watch tool calls unfold, and manage the current conversation.
---

# Chat

The chat page is the main interface for the AI assistant. Open it from the AI hub via **New conversation**, or tap a conversation in the chat history. If no API key or endpoint is configured yet, the page shows an "AI assistant not configured" prompt with an **Open settings** button that jumps to the [AI assistant settings](efa://manual/pages/ai/ai-settings).

The app bar contains:

- **Model picker** (only when configured) — the button shows the current model name. Tapping it opens a sheet to switch between saved models, **fetch models from server** (with a 30-second cooldown), or enter a **custom model**. Switching models keeps the current conversation.
- **New conversation** — clears the current conversation and starts fresh.
- **History** — opens the [chat history](efa://manual/pages/ai/ai-chat-history).

The conversation area:

- **Message bubbles** — your messages appear on the right (primary-tinted); assistant messages on the left (neutral). Assistant messages are rendered as Markdown and show a cursor while streaming; in-app links in messages (such as `efa://manual/…`) open directly.
- **Tool-call blocks** — each tool invocation appears as a collapsible narrow strip: an icon and the tool name, with a spinner while running and a checkmark when done. Expand it to see the **Input** (JSON arguments) and **Output** (tool result).
- **Error banner** — shown above the composer when a send fails, with the reason and a **Retry** button; you can also dismiss it and type again.

The composer at the bottom is a multi-line input (up to 5 lines) with a send button; while a turn is in flight the button becomes a spinner and the input is disabled.

While answering, the assistant can use two families of tools:

- **Manual tools** — the assistant can search and read the bundled user manual (`search_manual` / `get_manual_doc`), for example to explain "how do I import a fit". Manual tools require the selected model to support tool calling.
- **Fit tools** — when you have a fit open on the [fit page](efa://manual/pages/fitting/fit), that fit is attached to the conversation: the assistant can read the current fit, inspect attributes and stats, run fit validation, and propose edits via `propose_fit_edit` (`get_current_fit`, `get_fit_stats`, `get_item`, `get_attr`, `validate_fit`). It can also search items and list or load your saved fits (`search_items`, `list_user_fits`, `load_fit`).

The AI assistant is available on native platforms (Android, desktop) only; the web app does not include it.