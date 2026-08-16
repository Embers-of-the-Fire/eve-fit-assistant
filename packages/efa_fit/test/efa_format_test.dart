import "dart:convert";
import "dart:typed_data";

import "package:archive/archive.dart";
import "package:efa_fit/efa_fit.dart";
import "package:flutter_test/flutter_test.dart";

Map<String, dynamic> _makePayload({String name = "Test Fit"}) => <String, dynamic>{
  "version": 2,
  "fit": <String, dynamic>{
    "version": 2,
    "fit": <String, dynamic>{
      "metadata": <String, dynamic>{"fitId": "test-fit-1", "name": name},
    },
  },
};

String _makeLinkPayloadWithUrlUnsafeBytes() {
  for (var i = 0; i < 1000; i++) {
    final payload = _makePayload(name: "Test Fit $i");
    final standard = base64Encode(encodeEfaFitBinary(payload));
    if (standard.contains("+") || standard.contains("/")) {
      return encodeEfaFitLinkPayload(payload);
    }
  }
  throw StateError("Failed to produce a gzip stream with url-unsafe base64 bytes");
}

void main() {
  group("encodeEfaFitBinary/decodeEfaFitBinary", () {
    test("round-trips a JSON payload", () {
      final payload = _makePayload();
      expect(decodeEfaFitBinary(encodeEfaFitBinary(payload)), payload);
    });

    test("rejects non-gzip content", () {
      expect(
        () => decodeEfaFitBinary(Uint8List.fromList(utf8.encode("not gzip"))),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.invalidCompression,
          ),
        ),
      );
    });
  });

  group("encodeEfaFitLinkPayload", () {
    test("matches the text payload binary stage with the url-safe alphabet", () {
      final payload = _makePayload();
      final textStage = base64Encode(encodeEfaFitBinary(payload));

      final linkPayload = encodeEfaFitLinkPayload(payload);

      expect(linkPayload.startsWith("EFA2:"), isTrue);
      expect(linkPayload, matches(RegExp(r"^EFA2:[A-Za-z0-9_-]+$")));
      final textBytes = base64Decode(textStage);
      final linkBytes = base64Url.decode(
        base64Url.normalize(linkPayload.substring("EFA2:".length)),
      );
      expect(linkBytes, textBytes);
    });

    test("uses - and _ where standard base64 would use + and /", () {
      final payload = _makeLinkPayloadWithUrlUnsafeBytes();
      final encoded = payload.substring("EFA2:".length);
      expect(encoded.contains("+"), isFalse);
      expect(encoded.contains("/"), isFalse);
      expect(encoded.contains("="), isFalse);

      final decoded = decodeEfaFitLinkPayload(payload);
      final fit = decoded["fit"]! as Map<String, dynamic>;
      final storage = fit["fit"]! as Map<String, dynamic>;
      final metadata = storage["metadata"]! as Map<String, dynamic>;
      expect(metadata["fitId"], "test-fit-1");
    });
  });

  group("decodeEfaFitLinkPayload", () {
    test("round-trips a payload produced by encodeEfaFitLinkPayload", () {
      final payload = _makePayload();
      expect(decodeEfaFitLinkPayload(encodeEfaFitLinkPayload(payload)), payload);
    });

    test("rejects wrong prefixes including bare EFA:", () {
      for (final payload in ["EFA:abc", "EFA1:abc", "EFA3:abc", "efa2:abc", "abc"]) {
        expect(
          () => decodeEfaFitLinkPayload(payload),
          throwsA(
            isA<EfaFitFormatException>().having(
              (e) => e.code,
              "code",
              EfaFitFormatErrorCode.invalidPrefix,
            ),
          ),
        );
      }
    });

    test("rejects payloads above the encoded size cap", () {
      final oversized = "EFA2:${"A" * maxEfaFitLinkEncodedPayloadChars}";
      expect(
        () => decodeEfaFitLinkPayload(oversized),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.payloadTooLarge,
          ),
        ),
      );
    });

    test("rejects characters outside the base64url alphabet", () {
      final payload = encodeEfaFitLinkPayload(_makePayload());
      final tampered = "${payload.substring(0, 10)}+${payload.substring(11)}";
      expect(
        () => decodeEfaFitLinkPayload(tampered),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.invalidBase64,
          ),
        ),
      );
    });

    test("rejects non-gzip content", () {
      final payload = "EFA2:${base64UrlEncode(utf8.encode("not gzip")).replaceAll("=", "")}";
      expect(
        () => decodeEfaFitLinkPayload(payload),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.invalidCompression,
          ),
        ),
      );
    });

    test("rejects JSON content that is not an object", () {
      final compressed = const GZipEncoder().encodeBytes(utf8.encode("[1,2,3]"));
      final payload = "EFA2:${base64UrlEncode(compressed).replaceAll("=", "")}";
      expect(
        () => decodeEfaFitLinkPayload(payload),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.invalidJson,
          ),
        ),
      );
    });

    test("rejects inflated JSON above the decoded size cap", () {
      final huge = utf8.encode("[${"0," * (maxEfaFitDecodedJsonBytes ~/ 2)}0]");
      final compressed = const GZipEncoder().encodeBytes(huge);
      final payload = "EFA2:${base64UrlEncode(compressed).replaceAll("=", "")}";
      expect(
        () => decodeEfaFitLinkPayload(payload),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.decodedPayloadTooLarge,
          ),
        ),
      );
    });

    test("rejects a tiny gzip member that inflates far past the decoded size cap", () {
      final compressed = const GZipEncoder().encodeBytes(Uint8List(maxEfaFitDecodedJsonBytes * 4));
      final payload = "EFA2:${base64UrlEncode(compressed).replaceAll("=", "")}";
      expect(payload.length, lessThanOrEqualTo(maxEfaFitLinkEncodedPayloadChars));
      expect(
        () => decodeEfaFitLinkPayload(payload),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.decodedPayloadTooLarge,
          ),
        ),
      );
    });

    test("accepts inflated JSON at exactly the decoded size cap", () {
      final jsonText = '{"d":"${"0" * (maxEfaFitDecodedJsonBytes - 8)}"}';
      expect(utf8.encode(jsonText).length, maxEfaFitDecodedJsonBytes);
      final compressed = const GZipEncoder().encodeBytes(utf8.encode(jsonText));
      final payload = "EFA2:${base64UrlEncode(compressed).replaceAll("=", "")}";
      expect(payload.length, lessThanOrEqualTo(maxEfaFitLinkEncodedPayloadChars));
      final decoded = decodeEfaFitLinkPayload(payload);
      expect((decoded["d"]! as String).length, maxEfaFitDecodedJsonBytes - 8);
    });
  });

  group("EFA(n) text payloads", () {
    test("round-trips with the explicit current version", () {
      final payload = _makePayload();
      final text = encodeEfaFitTextPayload(payload);
      expect(text, startsWith("EFA2:"));

      final decoded = decodeEfaFitTextPayload(text);
      expect(decoded.prefixVersion, currentEfaFitFormatVersion);
      expect(decoded.json, payload);
    });

    test("accepts the legacy bare EFA: prefix as version 1", () {
      final payload = _makePayload();
      final text = "EFA:${base64Encode(encodeEfaFitBinary(payload))}";

      final decoded = decodeEfaFitTextPayload(text);
      expect(decoded.prefixVersion, legacyEfaFitFormatVersion);
      expect(decoded.json, payload);
    });

    test("rejects unknown prefix versions", () {
      for (final prefix in ["EFA0:", "EFA3:", "EFA99:"]) {
        final text = "$prefix${base64Encode(encodeEfaFitBinary(_makePayload()))}";
        expect(
          () => decodeEfaFitTextPayload(text),
          throwsA(
            isA<EfaFitFormatException>().having(
              (e) => e.code,
              "code",
              EfaFitFormatErrorCode.unsupportedVersion,
            ),
          ),
          reason: prefix,
        );
      }
    });

    test("rejects encoder versions outside the supported range", () {
      for (final version in [0, 3, 99]) {
        expect(
          () => encodeEfaFitTextPayload(_makePayload(), version: version),
          throwsA(isA<RangeError>()),
          reason: "version $version",
        );
      }
    });

    test("rejects payloads above the encoded size cap", () {
      final text = "EFA2:${"A" * (maxEfaFitTextEncodedPayloadChars + 1)}";
      expect(
        () => decodeEfaFitTextPayload(text),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.payloadTooLarge,
          ),
        ),
      );
    });

    test("rejects malformed base64 content", () {
      expect(
        () => decodeEfaFitTextPayload("EFA2:not_base64!!!"),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.invalidBase64,
          ),
        ),
      );
    });

    test("rejects non-gzip content", () {
      final text = "EFA2:${base64Encode(utf8.encode("not gzip"))}";
      expect(
        () => decodeEfaFitTextPayload(text),
        throwsA(
          isA<EfaFitFormatException>().having(
            (e) => e.code,
            "code",
            EfaFitFormatErrorCode.invalidCompression,
          ),
        ),
      );
    });
  });
}
