import "package:eve_fit_assistant/features/fit_link/fit_link_uri.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  const payload = "EFA2:abc-def_123";

  group("parseFitLinkUri", () {
    test("accepts the efa scheme form", () {
      final result = parseFitLinkUri(Uri.parse("efa://fit/raw?payload=$payload"));
      expect(result, isNotNull);
      expect(result!.payload, payload);
    });

    test("accepts the efa scheme without authority", () {
      final result = parseFitLinkUri(Uri.parse("efa:fit/raw?payload=$payload"));
      expect(result, isNotNull);
      expect(result!.payload, payload);
    });

    test("efa scheme and path are case-insensitive", () {
      final result = parseFitLinkUri(Uri.parse("EFA://FIT/RAW?payload=$payload"));
      expect(result, isNotNull);
      expect(result!.payload, payload);
    });

    test("accepts all three https hosts", () {
      for (final host in fitLinkHttpsHosts) {
        final result = parseFitLinkUri(Uri.parse("https://$host/fit/raw?payload=$payload"));
        expect(result, isNotNull, reason: host);
        expect(result!.payload, payload);
      }
    });

    test("https path is case-sensitive", () {
      expect(
        parseFitLinkUri(Uri.parse("https://$fitLinkShareHost/FIT/RAW?payload=$payload")),
        isNull,
      );
    });

    test("unknown hosts return null", () {
      expect(parseFitLinkUri(Uri.parse("https://example.com/fit/raw?payload=$payload")), isNull);
      expect(parseFitLinkUri(Uri.parse("https://efa-tech.dev/fit/raw?payload=$payload")), isNull);
    });

    test("unknown paths return null", () {
      expect(parseFitLinkUri(Uri.parse("efa://manual/fitting?payload=$payload")), isNull);
      expect(
        parseFitLinkUri(Uri.parse("https://$fitLinkShareHost/fit/id?payload=$payload")),
        isNull,
      );
      expect(parseFitLinkUri(Uri.parse("https://$fitLinkShareHost/?payload=$payload")), isNull);
    });

    test("other schemes return null", () {
      expect(
        parseFitLinkUri(Uri.parse("http://$fitLinkShareHost/fit/raw?payload=$payload")),
        isNull,
      );
    });

    test("extra query parameters are preserved and payload stays verbatim", () {
      final result = parseFitLinkUri(
        Uri.parse("https://$fitLinkShareHost/fit/raw?payload=$payload&utm_source=x&foo=bar"),
      );
      expect(result, isNotNull);
      expect(result!.payload, payload);
      expect(result.queryParameters["utm_source"], "x");
      expect(result.queryParameters["foo"], "bar");
    });

    test("missing payload returns null", () {
      expect(parseFitLinkUri(Uri.parse("efa://fit/raw")), isNull);
      expect(parseFitLinkUri(Uri.parse("https://$fitLinkShareHost/fit/raw")), isNull);
    });
  });

  group("buildShareUrl", () {
    test("builds the canonical share URL", () {
      expect(
        buildShareUrl(payload),
        "https://share.platform.efa-tech.dev/fit/raw?payload=$payload",
      );
    });
  });
}
