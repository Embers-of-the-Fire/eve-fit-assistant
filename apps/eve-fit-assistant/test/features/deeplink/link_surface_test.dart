import "package:eve_fit_assistant/features/deeplink/deeplink.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  final router = AppRouter();
  final surface = buildLinkSurface(router.routeCollection);

  group("buildLinkSurface", () {
    test("every annotated route has complete metadata", () {
      for (final route in router.routeCollection.routes) {
        if (route.meta[DeepLinkMeta.key] case final DeepLinkMeta meta) {
          expect(meta.title.trim(), isNotEmpty, reason: route.path);
          expect(meta.usage.trim(), isNotEmpty, reason: route.path);
        }
      }
    });

    test("every declared endpoint is matchable by the router", () {
      expect(surface.endpoints, isNotEmpty);
      for (final endpoint in surface.endpoints) {
        final probe = endpoint.isWildcard
            ? "${endpoint.path.substring(0, endpoint.path.length - 1)}probe"
            : endpoint.path;
        expect(router.matcher.match(probe), isNotNull, reason: endpoint.path);
      }
    });

    test("endpoints are sorted by path", () {
      final paths = surface.endpoints.map((e) => e.path).toList();
      expect(paths, orderedEquals(List<String>.of(paths)..sort()));
    });

    test("dynamic and developer-only routes are not exposed", () {
      final paths = surface.endpoints.map((e) => e.path);
      expect(paths, isNot(contains("/fitting/current")));
      expect(paths, isNot(contains("/setting/data/checkout-history")));
      expect(paths, isNot(contains("/manual/feedback")));
      expect(paths, isNot(contains("/setting/report-feedback")));
      expect(paths, isNot(contains("/announcements")));
      expect(paths, isNot(contains("/setting/developer-tools")));
      expect(paths, isNot(contains("/setting/developer-settings")));
      expect(paths, isNot(contains("/setting/channel-overview")));
    });
  });

  group("LinkSurface.containsUri", () {
    test("matches exact endpoints", () {
      expect(surface.containsUri("efa://"), isTrue);
      expect(surface.containsUri("efa://chat"), isTrue);
      expect(surface.containsUri("efa://chat/history"), isTrue);
    });

    test("matches wildcard sub-paths", () {
      expect(surface.containsUri("efa://manual/fitting"), isTrue);
      expect(surface.containsUri("efa://manual/getting-started/browse-ships"), isTrue);
      expect(surface.containsUri("efa://manual/"), isFalse);
    });

    test("rejects undeclared paths", () {
      expect(surface.containsUri("efa://fitting/current"), isFalse);
      expect(surface.containsUri("efa://setting/collect-logs"), isFalse);
      expect(surface.containsUri("efa://nope"), isFalse);
    });
  });

  group("renderLinkManifestForPrompt", () {
    final manifest = renderLinkManifestForPrompt(surface);

    test("renders every endpoint with its uri and title", () {
      for (final endpoint in surface.endpoints) {
        expect(manifest, contains(endpoint.uri), reason: endpoint.path);
        expect(manifest, contains(endpoint.title), reason: endpoint.path);
      }
    });

    test("renders wildcard endpoints as sub-path templates", () {
      expect(manifest, contains("efa://manual/<sub-path>"));
    });

    test("declares the scheme and forbids inventing paths", () {
      expect(manifest, contains("efa://"));
      expect(manifest, contains("never invent other paths"));
    });
  });
}
