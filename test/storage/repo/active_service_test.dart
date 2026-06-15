import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/active.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

void main() {
  late String tempDir;
  late ActiveService activeService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_active_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    activeService = ActiveService();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("ActiveService.readActive", () {
    test("returns None when active.json does not exist", () {
      expect(activeService.readActive(), const None());
    });
  });

  group("ActiveService write and read round-trip", () {
    test("round-trip with branchId", () async {
      final active = Active(
        schemaVersion: 2,
        branchId: "550e8400-e29b-41d4-a716-446655440000",
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        activatedAt: "2024-01-15T10:30:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
      );

      await activeService.writeActive(active);
      final restored = activeService.readActive();

      expect(restored.isSome(), isTrue);
      expect(restored.toNullable(), active);
    });

    test("round-trip with null branchId (detached mode)", () async {
      final active = Active(
        schemaVersion: 2,
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        activatedAt: "2024-01-15T10:30:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
      );

      await activeService.writeActive(active);
      final restored = activeService.readActive();

      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()?.branchId, isNull);
      expect(restored.toNullable(), active);
    });

    test("all fields survive round-trip", () async {
      final active = Active(
        schemaVersion: 2,
        branchId: "test-branch-id",
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd",
        activatedAt: "2024-12-25T00:00:00Z",
        serverId: "tranquility",
        metadata: GameMetadata(
          gameServer: "Tranquility",
          gameBuild: "22.01",
          gameVersion: "REVENANT",
        ),
      );

      await activeService.writeActive(active);

      final raw = jsonDecode(File(RepoPaths.activePath).readAsStringSync()) as Map<String, dynamic>;
      expect(raw["schemaVersion"], 2);
      expect(raw["branchId"], "test-branch-id");
      expect(raw["checkoutId"], "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd");
      expect(raw["serverId"], "tranquility");

      final restored = activeService.readActive().toNullable()!;
      expect(restored.schemaVersion, active.schemaVersion);
      expect(restored.branchId, active.branchId);
      expect(restored.checkoutId, active.checkoutId);
      expect(restored.activatedAt, active.activatedAt);
      expect(restored.serverId, active.serverId);
      expect(restored.metadata, active.metadata);
    });
  });

  group("ActiveService.getActiveBranchId", () {
    test("returns Some with branchId when set", () async {
      final active = Active(
        schemaVersion: 2,
        branchId: "my-branch",
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd",
        activatedAt: "2024-01-01T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
      );
      await activeService.writeActive(active);

      expect(activeService.getActiveBranchId(), const Some("my-branch"));
    });

    test("returns None when active.json is missing", () {
      expect(activeService.getActiveBranchId(), const None());
    });
  });

  group("ActiveService.isDetached", () {
    test("returns true when active.json is missing", () {
      expect(activeService.isDetached, isTrue);
    });

    test("returns true when branchId is null (detached mode)", () async {
      final active = Active(
        schemaVersion: 2,
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd",
        activatedAt: "2024-01-01T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
      );
      await activeService.writeActive(active);

      expect(activeService.isDetached, isTrue);
    });

    test("returns false when branchId is set", () async {
      final active = Active(
        schemaVersion: 2,
        branchId: "my-branch",
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd",
        activatedAt: "2024-01-01T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
      );
      await activeService.writeActive(active);

      expect(activeService.isDetached, isFalse);
    });
  });

  group("ActiveService.guardMutate", () {
    test("returns Some with message when active.json is missing", () {
      final result = activeService.guardMutate();
      expect(result.isSome(), isTrue);
      expect(result.toNullable(), contains("Detached"));
    });

    test("returns Some with message when branchId is null", () async {
      final active = Active(
        schemaVersion: 2,
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd",
        activatedAt: "2024-01-01T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
      );
      await activeService.writeActive(active);

      final result = activeService.guardMutate();
      expect(result.isSome(), isTrue);
    });

    test("returns None when branchId is set", () async {
      final active = Active(
        schemaVersion: 2,
        branchId: "my-branch",
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd",
        activatedAt: "2024-01-01T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
      );
      await activeService.writeActive(active);

      expect(activeService.guardMutate(), const None());
    });
  });
  group("ActiveService.getActiveCheckoutId", () {
    test("returns Some with checkoutId when set", () async {
      final active = Active(
        schemaVersion: 2,
        checkoutId: "1000000000abcdef0123456789abcdef0123456789abcdef0123456789abcd",
        activatedAt: "2024-01-01T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
      );
      await activeService.writeActive(active);

      expect(
        activeService.getActiveCheckoutId(),
        const Some("1000000000abcdef0123456789abcdef0123456789abcdef0123456789abcd"),
      );
    });

    test("returns None when active.json is missing", () {
      expect(activeService.getActiveCheckoutId(), const None());
    });
  });

  group("ActiveService atomic write", () {
    test("after write, no .tmp file remains", () async {
      final active = Active(
        schemaVersion: 2,
        checkoutId: "c000000000abcdef0123456789abcdef0123456789abcdef0123456789abcd",
        activatedAt: "2024-01-01T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
      );
      await activeService.writeActive(active);

      final tmpFile = File("${RepoPaths.activePath}.tmp");
      expect(tmpFile.existsSync(), isFalse);
      expect(File(RepoPaths.activePath).existsSync(), isTrue);
    });
  });
}
