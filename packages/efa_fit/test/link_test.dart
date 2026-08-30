import "package:efa_fit/efa_fit.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  const payload = "EFA2:abc-def_123";

  group("parseFitLinkUri", () {
    test("accepts the efa scheme form", () {
      final result = parseFitLinkUri(Uri.parse("efa://fit/raw?payload=$payload"));
      expect(result, isNotNull);
      expect((result! as FitLinkRaw).payload, payload);
    });

    test("accepts the efa scheme without authority", () {
      final result = parseFitLinkUri(Uri.parse("efa:fit/raw?payload=$payload"));
      expect(result, isNotNull);
      expect((result! as FitLinkRaw).payload, payload);
    });

    test("efa scheme and path are case-insensitive", () {
      final result = parseFitLinkUri(Uri.parse("EFA://FIT/RAW?payload=$payload"));
      expect(result, isNotNull);
      expect((result! as FitLinkRaw).payload, payload);
    });

    test("accepts the platform host with the platform path", () {
      final result = parseFitLinkUri(
        Uri.parse("https://$fitLinkPlatformHost$fitLinkPlatformPath?payload=$payload"),
      );
      expect(result, isNotNull);
      expect((result! as FitLinkRaw).payload, payload);
    });

    test("accepts all legacy https hosts with the canonical path", () {
      for (final host in fitLinkLegacyHttpsHosts) {
        final result = parseFitLinkUri(Uri.parse("https://$host/fit/raw?payload=$payload"));
        expect(result, isNotNull, reason: host);
        expect((result! as FitLinkRaw).payload, payload);
      }
    });

    test("rejects paths on the wrong host", () {
      expect(
        parseFitLinkUri(Uri.parse("https://$fitLinkPlatformHost/fit/raw?payload=$payload")),
        isNull,
      );
      expect(
        parseFitLinkUri(
          Uri.parse("https://$fitLinkLegacyShareHost/share/fit/raw?payload=$payload"),
        ),
        isNull,
      );
    });

    test("https path is case-sensitive", () {
      expect(
        parseFitLinkUri(Uri.parse("https://$fitLinkLegacyShareHost/FIT/RAW?payload=$payload")),
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
        parseFitLinkUri(Uri.parse("https://$fitLinkLegacyShareHost/fit/id?payload=$payload")),
        isNull,
      );
      expect(
        parseFitLinkUri(Uri.parse("https://$fitLinkLegacyShareHost/?payload=$payload")),
        isNull,
      );
    });

    test("other schemes return null", () {
      expect(
        parseFitLinkUri(Uri.parse("http://$fitLinkLegacyShareHost/fit/raw?payload=$payload")),
        isNull,
      );
    });

    test("extra query parameters are preserved and payload stays verbatim", () {
      final result = parseFitLinkUri(
        Uri.parse("https://$fitLinkLegacyShareHost/fit/raw?payload=$payload&utm_source=x&foo=bar"),
      );
      expect(result, isNotNull);
      expect((result! as FitLinkRaw).payload, payload);
      expect(result.queryParameters["utm_source"], "x");
      expect(result.queryParameters["foo"], "bar");
    });

    test("missing payload returns null", () {
      expect(parseFitLinkUri(Uri.parse("efa://fit/raw")), isNull);
      expect(parseFitLinkUri(Uri.parse("https://$fitLinkLegacyShareHost/fit/raw")), isNull);
    });
  });

  group("parseFitLinkBootUri", () {
    test("accepts the canonical path regardless of host", () {
      final result = parseFitLinkBootUri(Uri.parse("https://example.com/fit/raw?payload=$payload"));
      expect(result, isNotNull);
      expect((result! as FitLinkRaw).payload, payload);
    });

    test("rejects other paths", () {
      expect(parseFitLinkBootUri(Uri.parse("https://$fitLinkLegacyShareHost/fit?id=1")), isNull);
    });
  });

  group("buildFitLinkShareUrl", () {
    test("builds the canonical share URL", () {
      expect(
        buildFitLinkShareUrl(payload),
        "https://platform.efa-tech.dev/share/fit/raw?payload=$payload",
      );
    });

    test("rejects payloads without the EFA link prefix", () {
      expect(
        () => buildFitLinkShareUrl("abc-def_123"),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.invalidPrefix,
          ),
        ),
      );
    });

    test("rejects payloads containing query delimiters", () {
      for (final bad in ["$payload&x=1", "$payload#fragment", "$payload=pad", "$payload+plus"]) {
        expect(
          () => buildFitLinkShareUrl(bad),
          throwsA(
            isA<EfaFitFormatException>().having(
              (e) => e.code,
              "code",
              EfaFitFormatErrorCode.invalidBase64,
            ),
          ),
          reason: bad,
        );
      }
    });

    test("rejects payloads with an empty base64url tail", () {
      expect(
        () => buildFitLinkShareUrl("EFA2:"),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.invalidBase64,
          ),
        ),
      );
    });

    test("built URL round-trips through the parser unchanged", () {
      final url = buildFitLinkShareUrl(payload);
      final result = parseFitLinkUri(Uri.parse(url));
      expect(result, isNotNull);
      expect((result! as FitLinkRaw).payload, payload);
    });

    test("rejects URLs longer than maxFitLinkUrlLength", () {
      final longPayload = "$payload${"a" * maxFitLinkUrlLength}";
      expect(
        () => buildFitLinkShareUrl(longPayload),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.payloadTooLarge,
          ),
        ),
      );
    });
  });

  group("registered fit links", () {
    const fitHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    test("accepts the efa scheme form", () {
      final result = parseFitLinkUri(Uri.parse("efa://fit/registered?hash=$fitHash"));
      expect(result, isA<FitLinkRegistered>());
      expect((result! as FitLinkRegistered).fitHash, fitHash);
    });

    test("accepts the platform host with the registered platform path", () {
      final result = parseFitLinkUri(
        Uri.parse("https://$fitLinkPlatformHost$fitLinkRegisteredPlatformPath?hash=$fitHash"),
      );
      expect(result, isA<FitLinkRegistered>());
      expect((result! as FitLinkRegistered).fitHash, fitHash);
    });

    test("accepts the app hosts with the registered canonical path", () {
      for (final host in [fitLinkProdHost, fitLinkNightlyHost]) {
        final result = parseFitLinkUri(
          Uri.parse("https://$host$fitLinkRegisteredCanonicalPath?hash=$fitHash"),
        );
        expect(result, isA<FitLinkRegistered>(), reason: host);
        expect((result! as FitLinkRegistered).fitHash, fitHash);
      }
    });

    test("rejects registered paths on the wrong host", () {
      expect(
        parseFitLinkUri(Uri.parse("https://$fitLinkPlatformHost/fit/registered?hash=$fitHash")),
        isNull,
      );
      expect(
        parseFitLinkUri(
          Uri.parse("https://$fitLinkLegacyShareHost/share/fit/registered?hash=$fitHash"),
        ),
        isNull,
      );
    });

    test("rejects missing or malformed hashes", () {
      expect(parseFitLinkUri(Uri.parse("efa://fit/registered")), isNull);
      expect(parseFitLinkUri(Uri.parse("efa://fit/registered?hash=abc")), isNull);
      expect(
        parseFitLinkUri(Uri.parse("efa://fit/registered?hash=${fitHash.toUpperCase()}")),
        isNull,
      );
      expect(parseFitLinkUri(Uri.parse("efa://fit/registered?hash=${fitHash}00")), isNull);
    });

    test("extra query parameters are preserved", () {
      final result = parseFitLinkUri(Uri.parse("efa://fit/registered?hash=$fitHash&utm_source=x"));
      expect(result, isA<FitLinkRegistered>());
      expect(result!.queryParameters["utm_source"], "x");
    });

    test("boot probe accepts the registered canonical path on any host", () {
      final result = parseFitLinkBootUri(
        Uri.parse("https://example.com/fit/registered?hash=$fitHash"),
      );
      expect(result, isA<FitLinkRegistered>());
      expect((result! as FitLinkRegistered).fitHash, fitHash);
    });

    test("built registered share URL round-trips through the parser", () {
      final url = buildFitLinkRegisteredShareUrl(fitHash);
      expect(url, "https://platform.efa-tech.dev/share/fit/registered?hash=$fitHash");
      final result = parseFitLinkUri(Uri.parse(url));
      expect(result, isA<FitLinkRegistered>());
      expect((result! as FitLinkRegistered).fitHash, fitHash);
    });

    test("buildFitLinkRegisteredShareUrl rejects malformed hashes", () {
      expect(
        () => buildFitLinkRegisteredShareUrl("abc"),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.invalidHash,
          ),
        ),
      );
    });

    test("built registered app URI round-trips through the parser", () {
      final uri = buildFitLinkRegisteredAppUri(fitHash);
      expect(uri.toString(), "efa://fit/registered?hash=$fitHash");
      final result = parseFitLinkUri(uri);
      expect(result, isA<FitLinkRegistered>());
      expect((result! as FitLinkRegistered).fitHash, fitHash);
    });
  });
}
