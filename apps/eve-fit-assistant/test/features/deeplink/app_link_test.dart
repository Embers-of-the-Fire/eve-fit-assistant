import "package:eve_fit_assistant/features/deeplink/deeplink.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("parseAppLink", () {
    test("efa scheme maps to absolute in-app paths", () {
      final link = parseAppLink("efa://manual/fitting");
      expect(link, isA<InternalAppLink>());
      expect((link! as InternalAppLink).path, "/manual/fitting");
    });

    test("efa scheme tolerates extra slashes and normalizes dot segments", () {
      expect((parseAppLink("efa:///manual//fitting/")! as InternalAppLink).path, "/manual/fitting");
      expect(
        (parseAppLink("efa://manual/fitting/../getting-started")! as InternalAppLink).path,
        "/manual/getting-started",
      );
    });

    test("efa action links resolve to actions", () {
      final link = parseAppLink("efa://action/switch-channel");
      expect(link, isA<ActionAppLink>());
      expect((link! as ActionAppLink).name, "switch-channel");
    });

    test("action links tolerate extra slashes and a case-insensitive prefix", () {
      expect((parseAppLink("efa://action//switch-channel/")! as ActionAppLink).name,
          "switch-channel");
      expect((parseAppLink("efa://ACTION/switch-channel")! as ActionAppLink).name,
          "switch-channel");
    });

    test("the bare action prefix stays a route link", () {
      expect(parseAppLink("efa://action"), isA<InternalAppLink>());
      expect(parseAppLink("efa://action/"), isA<InternalAppLink>());
    });

    test("efa scheme is case-insensitive", () {
      expect((parseAppLink("EFA://manual/fitting")! as InternalAppLink).path, "/manual/fitting");
    });

    test("absolute paths stay in-app", () {
      expect(
        (parseAppLink("/manual/fitting/advanced")! as InternalAppLink).path,
        "/manual/fitting/advanced",
      );
    });

    test("http(s) links are external", () {
      final link = parseAppLink("https://www.eveonline.com");
      expect(link, isA<ExternalAppLink>());
      expect((link! as ExternalAppLink).uri.host, "www.eveonline.com");
    });

    test("other schemes are external", () {
      expect(parseAppLink("mailto:foo@bar.com"), isA<ExternalAppLink>());
    });

    test("relative links resolve against the base path", () {
      expect(
        (parseAppLink("modules", basePath: "/manual/fitting")! as InternalAppLink).path,
        "/manual/fitting/modules",
      );
      expect(
        (parseAppLink("./modules", basePath: "/manual/fitting")! as InternalAppLink).path,
        "/manual/fitting/modules",
      );
      expect(
        (parseAppLink("../modules", basePath: "/manual/fitting/advanced")! as InternalAppLink).path,
        "/manual/fitting/modules",
      );
      expect(
        (parseAppLink("../../getting-started/browse-ships", basePath: "/manual/fitting/advanced")!
                as InternalAppLink)
            .path,
        "/manual/getting-started/browse-ships",
      );
    });

    test("parent traversal clamps at the root", () {
      expect((parseAppLink("../../x", basePath: "/manual")! as InternalAppLink).path, "/x");
    });

    test("relative links default to the root as base", () {
      expect((parseAppLink("manual/fitting")! as InternalAppLink).path, "/manual/fitting");
    });

    test("empty input does not resolve", () {
      expect(parseAppLink(""), isNull);
      expect(parseAppLink("   "), isNull);
    });
  });
}
