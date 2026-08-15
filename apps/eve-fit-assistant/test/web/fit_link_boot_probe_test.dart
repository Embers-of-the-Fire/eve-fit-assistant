@TestOn("browser")
library;

import "package:eve_fit_assistant/features/fit_link/boot_probe.dart";
import "package:flutter_test/flutter_test.dart";
import "package:web/web.dart" as web;

void main() {
  tearDown(() {
    web.window.history.replaceState(null, "", "/");
  });

  test("stashes a fit link and scrubs the address bar", () {
    web.window.history.replaceState(null, "", "/fit/raw?payload=EFA2:abc-def_123");

    probeFitLinkBootUrl();

    expect(web.window.location.pathname, "/");
    final uri = takeBootFitLink();
    expect(uri, isNotNull);
    expect(uri!.path, "/fit/raw");
    expect(uri.queryParameters["payload"], "EFA2:abc-def_123");
    expect(takeBootFitLink(), isNull);
  });

  test("leaves non-fit paths alone", () {
    web.window.history.replaceState(null, "", "/manual/fitting");

    probeFitLinkBootUrl();

    expect(web.window.location.pathname, "/manual/fitting");
    expect(takeBootFitLink(), isNull);
  });

  test("captures links alongside hash-strategy fragment routes", () {
    web.window.history.replaceState(null, "", "/fit/raw?payload=EFA2:abc#/some/route");

    probeFitLinkBootUrl();

    expect(takeBootFitLink(), isNotNull);
    expect(web.window.location.pathname, "/");
  });
}
