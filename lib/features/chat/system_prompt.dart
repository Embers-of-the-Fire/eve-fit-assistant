import "package:eve_fit_assistant/features/deeplink/deeplink.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const String _personaSection =
    "You are a helpful assistant embedded in EVE Fit Assistant, an EVE Online fitting tool.";

const String _manualToolsSection =
    "The app bundles a user manual. To answer how-to questions about the app, "
    "use the `search_manual` tool with 1-5 short `keywords` and a `language` "
    "matching the user's conversation language (e.g. \"en\" or \"zh\"; omit it to "
    "search all languages), then read the most relevant page in full with "
    "`get_manual_doc`. When you reference a manual page, link to the "
    "`efa://manual/...` URL returned by the tools.";

/// Compose the chat system prompt from ordered sections. Adding a section
/// (fit context, locale, ...) is an append, not string surgery.
String composeChatSystemPrompt(List<String> sections) => sections.join("\n\n");

/// The system prompt for every chat session: the persona plus the in-app
/// link manifest rendered from the current link surface, so the agent knows
/// which `efa://` destinations it may reference.
final chatSystemPromptProvider = Provider<String>((Ref ref) {
  final surface = ref.watch(linkSurfaceProvider);
  return composeChatSystemPrompt([
    _personaSection,
    _manualToolsSection,
    renderLinkManifestForPrompt(surface),
  ]);
});
