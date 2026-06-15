import "dart:convert";

import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("Branch", () {
    test("JSON round-trip with full data", () {
      final branch = Branch(
        schemaVersion: 1,
        id: "550e8400-e29b-41d4-a716-446655440000",
        checkout: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
        source: BranchSource(channel: "stable", remoteCheckoutId: "remote-hash-001"),
        name: IMap({"en": "Serenity Stable", "zh": "晨曦稳定"}),
        pinned: false,
        reflog: IList([
          ReflogEntry(
            id: "diff-uuid-001",
            timestamp: "2024-01-15T10:30:00Z",
            from: "0000000000000000000000000000000000000000000000000000000000000000",
            to: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
          ),
        ]),
        diffs: IMap<String, Diff>({}),
      );
      final restored = Branch.fromJson(
        jsonDecode(jsonEncode(branch.toJson())) as Map<String, dynamic>,
      );
      expect(restored, branch);
    });

    test("JSON round-trip with empty collections", () {
      final branch = Branch(
        schemaVersion: 1,
        id: "550e8400-e29b-41d4-a716-446655440000",
        checkout: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
        source: BranchSource(channel: "stable"),
      );
      final restored = Branch.fromJson(
        jsonDecode(jsonEncode(branch.toJson())) as Map<String, dynamic>,
      );
      expect(restored.reflog.isEmpty, isTrue);
      expect(restored.diffs.isEmpty, isTrue);
      expect(restored.name.isEmpty, isTrue);
      expect(restored, branch);
    });

    test("fromJson with known shape", () {
      final json =
          jsonDecode(
                '{'
                '  "schemaVersion": 1,'
                '  "id": "550e8400-e29b-41d4-a716-446655440000",'
                '  "checkout": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",'
                '  "name": {"en": "Serenity Stable"},'
                '  "pinned": false,'
                '  "serverId": "serenity",'
                '  "metadata": {"gameServer": "Serenity", "gameBuild": "21.06", "gameVersion": "EQUINOX"},'
                '  "source": {"channel": "stable"},'
                '  "reflog": [],'
                '  "diffs": {}'
                '}',
              )
              as Map<String, dynamic>;
      final branch = Branch.fromJson(json);
      expect(branch.id, "550e8400-e29b-41d4-a716-446655440000");
      expect(branch.source.channel, "stable");
      expect(branch.source.remoteCheckoutId, isNull);
    });
  });

  group("BranchSource", () {
    test("JSON round-trip with remoteCheckoutId", () {
      final source = BranchSource(channel: "stable", remoteCheckoutId: "remote-hash-001");
      final restored = BranchSource.fromJson(
        jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
      );
      expect(restored, source);
    });

    test("JSON round-trip without remoteCheckoutId", () {
      final source = BranchSource(channel: "stable");
      final restored = BranchSource.fromJson(
        jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
      );
      expect(restored.remoteCheckoutId, isNull);
      expect(restored, source);
    });
  });
}
