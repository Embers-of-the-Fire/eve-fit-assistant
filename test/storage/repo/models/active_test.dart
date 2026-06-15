import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("Active", () {
    test("JSON round-trip with branchId", () {
      final active = Active(
        schemaVersion: 1,
        branchId: "550e8400-e29b-41d4-a716-446655440000",
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        activatedAt: "2024-01-15T10:30:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
      );
      final restored = Active.fromJson(
        jsonDecode(jsonEncode(active.toJson())) as Map<String, dynamic>,
      );
      expect(restored, active);
    });

    test("JSON round-trip with null branchId (detached)", () {
      final active = Active(
        schemaVersion: 1,
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        activatedAt: "2024-01-15T10:30:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
      );
      final restored = Active.fromJson(
        jsonDecode(jsonEncode(active.toJson())) as Map<String, dynamic>,
      );
      expect(restored.branchId, isNull);
      expect(restored, active);
    });

    test("fromJson with known shape", () {
      final json =
          jsonDecode(
                '{'
                '  "schemaVersion": 1,'
                '  "branchId": null,'
                '  "checkoutId": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",'
                '  "activatedAt": "2024-01-15T10:30:00Z",'
                '  "serverId": "serenity",'
                '  "metadata": {'
                '    "gameServer": "Serenity",'
                '    "gameBuild": "21.06",'
                '    "gameVersion": "EQUINOX"'
                '  }'
                '}',
              )
              as Map<String, dynamic>;
      final active = Active.fromJson(json);
      expect(active.schemaVersion, 1);
      expect(active.branchId, isNull);
      expect(active.checkoutId, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
    });
  });
}
