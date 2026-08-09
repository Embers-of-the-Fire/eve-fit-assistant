---
title: AI Assistant
summary: "Entry point to the AI assistant: enable the service, download the data it needs, then start a new conversation, browse history, or open AI settings."
---

# AI Assistant

The AI assistant is a built-in conversational assistant that can draw on the user manual and the fit you currently have open to answer questions and give suggestions. It is an online service: your conversations and fit data are sent to the third-party provider you configure, and its answers may be inaccurate or unsafe. The AI assistant is available on native platforms (Android, desktop) only; the web app does not include it.

Open it from the **AI Assistant** card on the workspace page. The first time you enter, a series of full-page states appears before the three entries are shown:

- **About the AI Service** — A one-time notice. Tap **I Understand** to continue. The assistant sends your conversations and fit data to a third-party provider, so please confirm you understand the risks.
- **Enable the AI Assistant** — Tap **Enable** to download the resource database the assistant needs and unlock conversational tools such as fit queries.
- **Downloading the AI resource database…** — Shows download progress; if the download fails (network error or failed integrity verification), tap **Retry**.
- **Data required** — The assistant depends on local data. If no data snapshot is downloaded yet or your data version is too old, tap **Manage data** to open [Storage](efa://manual/pages/data/storage) and download or update it; if only the resource database is missing, tap **Download data**.

Once enabled, the page lists three entries:

- **New conversation** — Opens the [chat page](efa://manual/pages/ai/ai-chat) to start a new conversation.
- **Chat History** — Opens the [chat history](efa://manual/pages/ai/ai-chat-history) to view, resume, or delete past conversations.
- **AI Assistant** (settings) — Opens the [AI assistant settings](efa://manual/pages/ai/ai-settings) to configure the provider, endpoint, API key, and models.

Before the first conversation, configure an API key and endpoint in the AI assistant settings; otherwise the chat page shows a "not configured" prompt.