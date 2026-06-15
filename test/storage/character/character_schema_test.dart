import "dart:convert";

import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:flutter_test/flutter_test.dart";

Map<String, dynamic> _roundTripJson(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

void main() {
  group("CharacterStorage v3 format", () {
    test("serializes with checkoutRef and no bundleId/bundleSnapshot", () {
      const character = CharacterStorage(
        characterId: "test-char-1",
        name: "Test Character",
        description: "A test character",
        lastModified: 0,
        checkoutRef: CheckoutRef(
          checkoutId: "checkout-abc",
          serverId: "Serenity",
          metadata: GameMetadata(
            gameServer: "Serenity",
            gameBuild: "21.06",
            gameVersion: "EQUINOX",
          ),
        ),
        skills: {123: 5, 456: 4},
      );

      final json = _roundTripJson(character.toJson());

      expect(json["characterId"], "test-char-1");
      final cr = json["checkoutRef"] as Map<String, dynamic>;
      expect(cr["checkoutId"], "checkout-abc");
      expect(cr["serverId"], "Serenity");
      expect(json["skills"], {"123": 5, "456": 4});

      // v3 should NOT serialize bundleId/bundleSnapshot
      expect(json.containsKey("bundleId"), isFalse);
      expect(json.containsKey("bundleSnapshot"), isFalse);
    });

    test("round-trips v3 character", () {
      const character = CharacterStorage(
        characterId: "test-char-2",
        name: "Round Trip",
        description: "",
        lastModified: 42,
        checkoutRef: CheckoutRef(
          checkoutId: "co-id",
          serverId: "Tranquility",
          metadata: GameMetadata(
            gameServer: "Tranquility",
            gameBuild: "21.06",
            gameVersion: "EQUINOX",
          ),
        ),
        skills: {1: 1, 2: 2},
      );

      final json = _roundTripJson(character.toJson());
      final decoded = CharacterStorage.fromJson(json);

      expect(decoded.characterId, character.characterId);
      expect(decoded.name, character.name);
      expect(decoded.lastModified, character.lastModified);
      expect(decoded.checkoutRef.checkoutId, character.checkoutRef.checkoutId);
      expect(decoded.checkoutRef.serverId, character.checkoutRef.serverId);
      expect(decoded.skills, {1: 1, 2: 2});
    });
  });

  group("CharacterStorage v2 is unsupported", () {
    test("fromJson throws on v2 payload without checkoutRef", () {
      final v2Json = <String, dynamic>{
        "characterId": "v2-char",
        "name": "V2 Character",
        "description": "Old format",
        "lastModified": 1,
        "bundleId": "Serenity-21.06-EQUINOX",
        "bundleSnapshot": "snap-42",
        "skills": <String, dynamic>{"123": 5},
      };

      // v2 is unsupported — fromJson should fail because checkoutRef is required
      expect(() => CharacterStorage.fromJson(v2Json), throwsA(isA<TypeError>()));
    });

    test("v2 character with existing checkoutRef decodes correctly", () {
      final v2Json = <String, dynamic>{
        "characterId": "c",
        "name": "C",
        "description": "",
        "lastModified": 0,
        "checkoutRef": <String, dynamic>{
          "checkoutId": "existing-checkout",
          "serverId": "Serenity",
          "metadata": <String, dynamic>{
            "gameServer": "Serenity",
            "gameBuild": "21.06",
            "gameVersion": "EQUINOX",
          },
        },
        "bundleSnapshot": "should-ignore",
        "skills": <String, dynamic>{},
      };

      final decoded = CharacterStorage.fromJson(v2Json);
      expect(decoded.checkoutRef.checkoutId, "existing-checkout");
      expect(decoded.checkoutRef.serverId, "Serenity");
    });
  });

  group("CharacterStorage built-in sentinel", () {
    test("empty checkoutId for sentinel characters", () {
      const character = CharacterStorage(
        characterId: predefinedMaxCharacterId,
        name: "All V",
        description: "Built-in",
        lastModified: 0,
        checkoutRef: CheckoutRef(
          checkoutId: "",
          serverId: "",
          metadata: GameMetadata(gameServer: "", gameBuild: "", gameVersion: ""),
        ),
        skills: <int, int>{},
      );

      expect(character.checkoutRef.checkoutId, "");
      expect(character.checkoutRef.serverId, "");
    });
  });
}
