import "package:eve_fit_assistant/features/deeplink/deeplink.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const String _personaSection =
    "You are a helpful assistant embedded in EVE Fit Assistant, an EVE Online fitting tool.";

/// Compose the chat system prompt from ordered sections. Adding a section
/// (fit context, locale, ...) is an append, not string surgery.
String composeChatSystemPrompt(List<String> sections) => sections.join("\n\n");

/// The system prompt for every chat session: the persona plus the in-app
/// link manifest rendered from the current link surface, so the agent knows
/// which `efa://` destinations it may reference.
final chatSystemPromptProvider = Provider<String>((Ref ref) {
  final surface = ref.watch(linkSurfaceProvider);
  return composeChatSystemPrompt([_personaSection, renderLinkManifestForPrompt(surface)]);
});
