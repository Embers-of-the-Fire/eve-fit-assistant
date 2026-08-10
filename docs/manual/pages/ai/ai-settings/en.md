---
title: AI Assistant Settings
summary: Configure the provider, endpoint, API key, and models, test the connection, and manage AI data.
---

# AI Assistant Settings

The AI assistant settings page configures the connection and models used by the chat service. Open it from the AI hub via the **AI Assistant** settings entry. API keys are stored in the system's secure storage only; they are never written to ordinary settings files.

The page is organized into the following sections.

**Connection**

- **Provider** — choose **OpenAI-compatible**, **Anthropic**, or **DeepSeek**. Each provider keeps its own endpoint, model, and model list. Note that tool features such as manual search require a model with tool-calling support (e.g. `deepseek-chat`; `deepseek-reasoner` and some self-hosted servers do not support it).
- **Endpoint** — the base URL of the service; leave empty to use the provider's default.
- **API Key** — enter your API key. Once configured the row shows "Configured" (only that, never the key itself), with a clear-key button.

**Models**

- **Default model** — pick the model used by the current provider from the saved models.
- **Fetch models from server** — asks the provider for its model list and saves them as choices (the first model is auto-selected if none is chosen yet). Fetches share a 30-second cooldown, so the action is temporarily disabled after a request; a missing API key is reported. The number of fetched models is shown in a snackbar.
- **Model list** — lists the saved models (with owner info when known) with a remove button each, plus **Add model** to type a name manually.

**Actions**

- **Test connection** — sends a test message to the current configuration to verify endpoint, key, and model.
- **Clear conversations** — deletes all saved conversations after confirmation.
- **Re-download AI data** — force-refreshes and re-downloads the assistant's resource database, useful when the data is corrupt or behaving oddly.

**Disable the AI Assistant** — confirms and turns off the global assistant switch, returning the gate to the "Enable" state; re-enabling does not require the notice to be read again.

The AI assistant is available on native platforms (Android, desktop) only; the web app does not include it. For how to converse and what the assistant can do, see the [chat page](efa://manual/pages/ai/ai-chat).