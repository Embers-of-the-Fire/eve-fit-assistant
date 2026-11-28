@TestOn("vm")
library;

import "package:eve_fit_assistant/components/model/ship_model_resolution.dart";
import "package:eve_fit_assistant/storage/repo/model_asset.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("resolveShipModelVariant", () {
    test("textured default resolves to textured without fallback", () {
      final resolution = resolveShipModelVariant(
        preferred: ShipModelVariant.textured,
        hasVariant: (_) => true,
      );

      expect(resolution.variant, ShipModelVariant.textured);
      expect(resolution.fallbackKind, ShipModelFallbackKind.none);
      expect(resolution.isFallback, isFalse);
      expect(resolution.isUnavailable, isFalse);
    });

    test("missing textured falls back to geometry-only with downgrade kind", () {
      final resolution = resolveShipModelVariant(
        preferred: ShipModelVariant.textured,
        hasVariant: (variant) => variant == ShipModelVariant.geometryOnly,
      );

      expect(resolution.variant, ShipModelVariant.geometryOnly);
      expect(resolution.fallbackKind, ShipModelFallbackKind.downgradedToGeometryOnly);
      expect(resolution.isFallback, isTrue);
      expect(resolution.isUnavailable, isFalse);
    });

    test("explicit geometry-only preference resolves without fallback", () {
      final resolution = resolveShipModelVariant(
        preferred: ShipModelVariant.geometryOnly,
        hasVariant: (_) => true,
      );

      expect(resolution.variant, ShipModelVariant.geometryOnly);
      expect(resolution.fallbackKind, ShipModelFallbackKind.none);
      expect(resolution.isFallback, isFalse);
    });

    test("preferred geometry-only missing uses textured with upgrade kind only", () {
      final resolution = resolveShipModelVariant(
        preferred: ShipModelVariant.geometryOnly,
        hasVariant: (variant) => variant == ShipModelVariant.textured,
      );

      expect(resolution.variant, ShipModelVariant.textured);
      expect(resolution.fallbackKind, ShipModelFallbackKind.upgradedToTextured);
      expect(resolution.isFallback, isTrue);
      expect(resolution.fallbackKind, isNot(ShipModelFallbackKind.downgradedToGeometryOnly));
    });

    test("no variant available reports unavailable", () {
      final resolution = resolveShipModelVariant(
        preferred: ShipModelVariant.textured,
        hasVariant: (_) => false,
      );

      expect(resolution.variant, isNull);
      expect(resolution.isUnavailable, isTrue);
      expect(resolution.isFallback, isFalse);
    });
  });
}
