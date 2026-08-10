---
name: app-usage
description: Answer questions about how to use the app's pages, settings, and features, grounded in the bundled user manual
---

# App usage questions

Use this skill when the user asks how to do something in EVE Fit Assistant:
what a page or setting does, where to find a feature, or how to accomplish a
task in the app. Do NOT use it for questions about fits, items, or stats —
those are served by the fit tools and the other skills.

The bundled manual is written for human readers, not as a lookup table, so
search it deliberately instead of expecting one query to hit the right page.

## Procedure

1. Extract 1-5 short keywords from the question, in the user's conversation
   language, and call `search_manual` with `language` set to that language
   (e.g. "en" or "zh").
2. If there are no hits, or none look relevant, retry once or twice with
   synonyms or broader terms; as a last resort omit `language` to search all
   localizations.
3. Read the most relevant hit in full with `get_manual_doc` before answering.
   Never answer from a search snippet alone — snippets are for ranking only.
4. If that page references another page that matters for the answer, read
   that one too.
5. Answer in the user's language, as concrete steps.

## Answer contract

- Link to the manual pages you used with the `efa://manual/...` URLs returned
  by the tools; never invent or guess URLs.
- Describe only behavior the manual actually documents. If the manual does
  not cover the question after the retries above, say so plainly instead of
  guessing at UI paths or feature names.
