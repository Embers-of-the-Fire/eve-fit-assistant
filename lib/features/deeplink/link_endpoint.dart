import "package:eve_fit_assistant/features/deeplink/app_link.dart";

/// A linkable route endpoint, derived from a `DeepLinkMeta` route annotation.
///
/// Pure data model: it carries no Flutter/router dependencies and no
/// rendering logic (see `render/prompt_renderer.dart` for prompt output).
class LinkEndpoint {
  const LinkEndpoint({required this.path, required this.title, required this.usage});

  /// The route path template, e.g. `/chat` or `/manual/*`.
  final String path;

  /// Short label of the destination page.
  final String title;

  /// When linking here is appropriate, phrased for the chat agent.
  final String usage;

  /// Whether this endpoint matches a sub-path space (`/manual/*`).
  bool get isWildcard => path.endsWith("/*");

  /// The `efa://` URI form of this endpoint as shown to the agent.
  String get uri {
    if (path == "/") return "$appLinkScheme://";
    if (isWildcard) return "$uriPrefix<sub-path>";
    return "$appLinkScheme://${path.substring(1)}";
  }

  /// For wildcard endpoints, the URI prefix concrete links start with,
  /// e.g. `efa://manual/`.
  String get uriPrefix {
    assert(isWildcard, "uriPrefix is only meaningful for wildcard endpoints");
    return "$appLinkScheme://${path.substring(1, path.length - 1)}";
  }
}
