import "package:eve_fit_assistant/features/deeplink/deeplink.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Extra system-prompt sections appended after the bundled base prompt
/// (persona + manual-tool usage, compiled into the efa-chat crate from
/// `rust/lib/efa-chat/prompt/system.prompt.txt`): the in-app link manifest
/// rendered from the current link surface, so the agent knows which `efa://`
/// destinations it may reference.
final chatSystemPromptProvider = Provider<String>((Ref ref) {
  final surface = ref.watch(linkSurfaceProvider);
  return renderLinkManifestForPrompt(surface);
});
