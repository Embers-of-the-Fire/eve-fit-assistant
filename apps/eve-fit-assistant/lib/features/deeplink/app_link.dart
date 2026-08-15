/// Link model and resolution for in-app content links.
///
/// This module is the single entry point for interpreting URLs found in
/// bundled or remote content (manual docs, announcements, ...). It is kept
/// free of BuildContext/router dependencies so a future OS-level deeplink
/// and redirect handler can reuse the same parsing and resolution logic.
library;

/// URL scheme for in-app links, e.g. `efa://manual/fitting`.
const String appLinkScheme = "efa";

/// A resolved link target.
sealed class AppLink {
  const AppLink();
}

/// An in-app destination. [path] is always an absolute route path starting
/// with `/`, e.g. `/manual/fitting/advanced`.
final class InternalAppLink extends AppLink {
  const InternalAppLink(this.path);

  final String path;
}

/// A destination outside the app (http(s), mailto, ...).
final class ExternalAppLink extends AppLink {
  const ExternalAppLink(this.uri);

  final Uri uri;
}

/// Parse [rawUrl] into an [AppLink].
///
/// Supported forms:
/// - `efa://<path>` — in-app link; the part after the scheme becomes the
///   absolute route path (`efa://manual/fitting` -> `/manual/fitting`).
/// - `/<path>` — in-app absolute route path.
/// - `<scheme>://...` — external link (http, https, mailto, ...).
/// - anything else — in-app path relative to [basePath], supporting `.` and
///   `..` segments. [basePath] is an absolute route path treated as the
///   directory the link appears in; it defaults to `/`.
///
/// Returns `null` for empty or unparseable input.
AppLink? parseAppLink(String rawUrl, {String basePath = "/"}) {
  final url = rawUrl.trim();
  if (url.isEmpty) return null;

  if (url.toLowerCase().startsWith("$appLinkScheme://")) {
    final rest = url.substring("$appLinkScheme://".length);
    return InternalAppLink(_joinAbsolute(const [], rest));
  }

  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.hasScheme) return ExternalAppLink(uri);

  if (url.startsWith("/")) {
    return InternalAppLink(_joinAbsolute(const [], url));
  }
  return InternalAppLink(_joinAbsolute(_segmentsOf(basePath), url));
}

/// Resolve [relative] against [baseSegments], normalizing `.`, `..`, and
/// empty segments. `..` at the root is clamped (ignored).
String _joinAbsolute(List<String> baseSegments, String relative) {
  final segments = List<String>.of(baseSegments);
  for (final segment in relative.split("/")) {
    if (segment.isEmpty || segment == ".") continue;
    if (segment == "..") {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  return "/${segments.join("/")}";
}

List<String> _segmentsOf(String path) =>
    path.split("/").where((segment) => segment.isNotEmpty).toList();
