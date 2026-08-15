import "dart:convert";
import "dart:typed_data";

import "package:archive/archive.dart";
import "package:eve_fit_assistant/features/fit_link/codec.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitStorage _makeFit({String name = "Test Fit"}) => FitStorage(
  metadata: FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 12017,
    name: name,
    lastModified: 0,
    description: "",
    checkoutRef: const CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: const FitStorageBody(
    shipTypeId: 12017,
    characterId: "predefined_all_5",
    damageProfile: FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    slots: FitStorageSlots(
      high: IList.empty(),
      medium: IList.empty(),
      low: IList.empty(),
      rig: IList.empty(),
      subsystem: IList.empty(),
      service: IList.empty(),
      tacticalMode: None(),
    ),
    drones: IList.empty(),
    fighters: IList.empty(),
    implants: IList.empty(),
    boosters: IList.empty(),
  ),
  dynamicRegistry: const FitDynamicRegistry(dynamicItems: IMap.empty()),
);

String _makeLinkPayloadWithUrlUnsafeBytes() {
  for (var i = 0; i < 1000; i++) {
    final fit = _makeFit(name: "Test Fit $i");
    final compressed = encodeNativeFitBinary(fit);
    final standard = base64Encode(compressed);
    if (standard.contains("+") || standard.contains("/")) {
      return encodeFitLinkPayload(fit);
    }
  }
  throw StateError("Failed to produce a gzip stream with url-unsafe base64 bytes");
}

void main() {
  group("encodeFitLinkPayload", () {
    test("matches the text export binary stage with the url-safe alphabet", () {
      final fit = _makeFit();
      final textStage = base64Encode(encodeNativeFitBinary(fit));

      final linkPayload = encodeFitLinkPayload(fit);

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

      final jsonBytes = decodeFitLinkPayload(payload);
      final decoded = decodeNativeFitPayload(
        jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>,
      );
      expect(decoded.fit.metadata.fitId, "test-fit-1");
    });
  });

  group("decodeFitLinkPayload", () {
    test("round-trips a payload produced by encodeFitLinkPayload", () {
      final fit = _makeFit();
      final jsonBytes = decodeFitLinkPayload(encodeFitLinkPayload(fit));
      final decoded = decodeNativeFitPayload(
        jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>,
      );
      expect(decoded.fit.metadata.name, "Test Fit");
    });

    test("rejects wrong prefixes including bare EFA:", () {
      for (final payload in ["EFA:abc", "EFA1:abc", "EFA3:abc", "efa2:abc", "abc"]) {
        expect(
          () => decodeFitLinkPayload(payload),
          throwsA(
            isA<FitLinkFormatException>().having(
              (e) => e.code,
              "code",
              FitLinkFormatErrorCode.invalidPrefix,
            ),
          ),
        );
      }
    });

    test("rejects payloads above the encoded size cap", () {
      final oversized = "EFA2:${"A" * maxFitLinkEncodedPayloadChars}";
      expect(
        () => decodeFitLinkPayload(oversized),
        throwsA(
          isA<FitLinkFormatException>().having(
            (e) => e.code,
            "code",
            FitLinkFormatErrorCode.payloadTooLarge,
          ),
        ),
      );
    });

    test("rejects characters outside the base64url alphabet", () {
      final payload = encodeFitLinkPayload(_makeFit());
      final tampered = "${payload.substring(0, 10)}+${payload.substring(11)}";
      expect(
        () => decodeFitLinkPayload(tampered),
        throwsA(
          isA<FitLinkFormatException>().having(
            (e) => e.code,
            "code",
            FitLinkFormatErrorCode.invalidBase64,
          ),
        ),
      );
    });

    test("rejects non-gzip content", () {
      final payload = "EFA2:${base64UrlEncode(utf8.encode("not gzip")).replaceAll("=", "")}";
      expect(
        () => decodeFitLinkPayload(payload),
        throwsA(
          isA<FitLinkFormatException>().having(
            (e) => e.code,
            "code",
            FitLinkFormatErrorCode.invalidCompression,
          ),
        ),
      );
    });

    test("rejects inflated JSON above the decoded size cap", () {
      final huge = utf8.encode("[${"0," * (maxFitLinkDecodedJsonBytes ~/ 2)}0]");
      final compressed = const GZipEncoder().encodeBytes(huge);
      final payload = "EFA2:${base64UrlEncode(compressed).replaceAll("=", "")}";
      expect(
        () => decodeFitLinkPayload(payload),
        throwsA(
          isA<FitLinkFormatException>().having(
            (e) => e.code,
            "code",
            FitLinkFormatErrorCode.decodedPayloadTooLarge,
          ),
        ),
      );
    });

    test("rejects a tiny gzip member that inflates far past the decoded size cap", () {
      final compressed = const GZipEncoder().encodeBytes(Uint8List(maxFitLinkDecodedJsonBytes * 4));
      final payload = "EFA2:${base64UrlEncode(compressed).replaceAll("=", "")}";
      expect(payload.length, lessThanOrEqualTo(maxFitLinkEncodedPayloadChars));
      expect(
        () => decodeFitLinkPayload(payload),
        throwsA(
          isA<FitLinkFormatException>().having(
            (e) => e.code,
            "code",
            FitLinkFormatErrorCode.decodedPayloadTooLarge,
          ),
        ),
      );
    });

    test("accepts inflated JSON at exactly the decoded size cap", () {
      final atCap = utf8.encode("[${"0" * (maxFitLinkDecodedJsonBytes - 2)}]");
      expect(atCap.length, maxFitLinkDecodedJsonBytes);
      final compressed = const GZipEncoder().encodeBytes(atCap);
      final payload = "EFA2:${base64UrlEncode(compressed).replaceAll("=", "")}";
      expect(payload.length, lessThanOrEqualTo(maxFitLinkEncodedPayloadChars));
      expect(decodeFitLinkPayload(payload).length, maxFitLinkDecodedJsonBytes);
    });
  });
}
