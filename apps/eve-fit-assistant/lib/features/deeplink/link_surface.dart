import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/deeplink/deeplink_meta.dart";
import "package:eve_fit_assistant/features/deeplink/link_endpoint.dart";

/// The linkable route surface: every endpoint the chat agent may reference,
/// derived from [DeepLinkMeta] route annotations.
class LinkSurface {
  const LinkSurface(this.endpoints);

  /// All linkable endpoints, sorted by path.
  final List<LinkEndpoint> endpoints;

  /// Whether [uri] (e.g. `efa://chat`, `efa://manual/fitting`) addresses a
  /// declared endpoint. Wildcard endpoints match any non-empty sub-path.
  bool containsUri(String uri) {
    for (final endpoint in endpoints) {
      if (endpoint.uri == uri) return true;
      if (endpoint.isWildcard &&
          uri.startsWith(endpoint.uriPrefix) &&
          uri.length > endpoint.uriPrefix.length) {
        return true;
      }
    }
    return false;
  }
}

/// Build the [LinkSurface] from a route collection. The collection is
/// injected so this module stays free of router/page dependencies.
LinkSurface buildLinkSurface(RouteCollection routes) => LinkSurface(
  [
    for (final route in routes.routes)
      if (route.meta[DeepLinkMeta.key] case final DeepLinkMeta meta)
        LinkEndpoint(path: route.path, title: meta.title, usage: meta.usage),
  ]..sort((a, b) => a.path.compareTo(b.path)),
);
