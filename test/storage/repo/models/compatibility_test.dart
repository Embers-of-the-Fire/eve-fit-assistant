import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/compatibility.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("CompatibilityResult", () {
    test("has three variants", () {
      expect(CompatibilityResult.values, hasLength(3));
      expect(
        CompatibilityResult.values,
        containsAll([
          CompatibilityResult.compatible,
          CompatibilityResult.incompatible,
          CompatibilityResult.outdated,
        ]),
      );
    });

    test("enum toJson produces name", () {
      final encoded = const CompatibilityCheck(result: CompatibilityResult.compatible).toJson();
      // Round-trip through jsonEncode/jsonDecode so enum serialization kicks in
      final decoded = jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>;
      expect(decoded["result"], "compatible");
    });

    test("fromJson restores all variants", () {
      for (final result in CompatibilityResult.values) {
        final json = jsonDecode(jsonEncode({"result": result.name})) as Map<String, dynamic>;
        final check = CompatibilityCheck.fromJson(json);
        expect(check.result, result);
      }
    });
  });

  group("CompatibilityCheck", () {
    test("JSON round-trip", () {
      for (final result in CompatibilityResult.values) {
        final check = CompatibilityCheck(result: result);
        final restored = CompatibilityCheck.fromJson(
          jsonDecode(jsonEncode(check.toJson())) as Map<String, dynamic>,
        );
        expect(restored, check);
      }
    });
  });

  group("CheckoutResolution", () {
    test("Compatible — exhaustiveness via switch", () {
      final resolution = const CheckoutResolutionCompatible();
      final result = switch (resolution) {
        CheckoutResolutionCompatible() => "compatible",
        _ => "other",
      };
      expect(result, "compatible");
    });

    test("OfferReSync — construction and field access", () {
      const resolution = CheckoutResolutionOfferReSync(
        checkoutId: "abc123",
        branchCheckoutId: "def456",
      );
      expect(resolution, isA<CheckoutResolutionOfferReSync>());
      expect(resolution.checkoutId, "abc123");
      expect(resolution.branchCheckoutId, "def456");
    });

    test("OfferDownload — construction and field access", () {
      const resolution = CheckoutResolutionOfferDownload(checkoutId: "abc123");
      expect(resolution, isA<CheckoutResolutionOfferDownload>());
      expect(resolution.checkoutId, "abc123");
    });

    test("Approximate — construction and field access", () {
      const resolution = CheckoutResolutionApproximate(checkoutId: "abc123");
      expect(resolution, isA<CheckoutResolutionApproximate>());
      expect(resolution.checkoutId, "abc123");
    });

    test("sealed class exhaustiveness — all four variants compile", () {
      final CheckoutResolution resolution = const CheckoutResolutionCompatible();
      final label = switch (resolution) {
        CheckoutResolutionCompatible() => "compatible",
        CheckoutResolutionOfferReSync() => "re-sync",
        CheckoutResolutionOfferDownload() => "download",
        CheckoutResolutionApproximate() => "approximate",
      };
      expect(label, isA<String>());
    });
  });
}
