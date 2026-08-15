import "package:eve_fit_assistant/features/deeplink/app_link.dart";
import "package:eve_fit_assistant/features/deeplink/link_surface.dart";

/// Render [surface] as the markdown section injected into the chat agent's
/// system prompt. This is the only place where the prompt serialization of
/// the link surface lives.
String renderLinkManifestForPrompt(LinkSurface surface) {
  final buffer = StringBuffer()
    ..writeln("## In-app links")
    ..writeln()
    ..writeln(
      "This app supports internal links using the `$appLinkScheme://` scheme. When one of "
      "the destinations below is relevant to the user's request, reference it with a standard "
      "markdown link, e.g. `[label]($appLinkScheme://chat)`. Use only the endpoints listed "
      "here and never invent other paths.",
    );
  for (final endpoint in surface.endpoints) {
    buffer.writeln("- `${endpoint.uri}` — ${endpoint.title}: ${endpoint.usage}");
  }
  return buffer.toString();
}
