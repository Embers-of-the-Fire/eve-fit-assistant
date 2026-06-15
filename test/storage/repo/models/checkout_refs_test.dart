import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/checkout_refs.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("CheckoutRefs", () {
    test("JSON round-trip with refs", () {
      final refs = CheckoutRefs(
        schemaVersion: 1,
        refs: IMap({
          "hash-a": CheckoutRefRecord(
            id: "hash-a",
            parentCheckoutId: null,
            installedAt: "2024-01-15T10:30:00Z",
            remoteCreatedAt: "2024-01-15T00:00:00Z",
            serverId: "serenity",
            metadata: GameMetadata(
              gameServer: "Serenity",
              gameBuild: "21.06",
              gameVersion: "EQUINOX",
            ),
          ),
        }),
      );
      final restored = CheckoutRefs.fromJson(
        jsonDecode(jsonEncode(refs.toJson())) as Map<String, dynamic>,
      );
      expect(restored, refs);
      expect(restored.refs["hash-a"]!.parentCheckoutId, isNull);
    });

    test("JSON round-trip with parentCheckoutId", () {
      final refs = CheckoutRefs(
        schemaVersion: 1,
        refs: IMap({
          "hash-b": CheckoutRefRecord(
            id: "hash-b",
            parentCheckoutId: "hash-a",
            installedAt: "2024-01-16T10:30:00Z",
            remoteCreatedAt: "2024-01-16T00:00:00Z",
            serverId: "serenity",
            metadata: GameMetadata(
              gameServer: "Serenity",
              gameBuild: "21.07",
              gameVersion: "EQUINOX",
            ),
          ),
        }),
      );
      final restored = CheckoutRefs.fromJson(
        jsonDecode(jsonEncode(refs.toJson())) as Map<String, dynamic>,
      );
      expect(restored.refs["hash-b"]!.parentCheckoutId, "hash-a");
    });

    test("JSON round-trip with empty refs", () {
      final refs = CheckoutRefs(schemaVersion: 1);
      final restored = CheckoutRefs.fromJson(
        jsonDecode(jsonEncode(refs.toJson())) as Map<String, dynamic>,
      );
      expect(restored.refs.isEmpty, isTrue);
      expect(restored, refs);
    });
  });
}
