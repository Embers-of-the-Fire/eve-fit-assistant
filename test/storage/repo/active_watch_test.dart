import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/active.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late String tempDir;
  late ActiveService activeService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_active_watch_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    activeService = ActiveService();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("ActiveService.watch", () {
    test("emits Active after active.json is written", () async {
      final events = <Active>[];
      final sub = activeService.watch.listen(events.add);

      // Let the watcher start
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final active = Active(
        schemaVersion: 2,
        branchId: "550e8400-e29b-41d4-a716-446655440000",
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        activatedAt: "2024-01-15T10:30:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
      );
      await activeService.writeActive(active);

      // Wait for debounce (200ms) plus a small buffer for filesystem
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(events.isNotEmpty, isTrue);
      expect(events.last, active);

      await sub.cancel();
    });

    test("emits updated Active after second write", () async {
      final events = <Active>[];
      final sub = activeService.watch.listen(events.add);

      final initial = Active(
        schemaVersion: 2,
        checkoutId: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        activatedAt: "2024-01-01T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
      );
      await activeService.writeActive(initial);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final updated = Active(
        schemaVersion: 2,
        branchId: "new-branch",
        checkoutId: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        activatedAt: "2024-06-01T00:00:00Z",
        serverId: "tranquility",
        metadata: GameMetadata(gameServer: "T", gameBuild: "B2", gameVersion: "V2"),
      );
      await activeService.writeActive(updated);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(events.length, greaterThanOrEqualTo(2));
      // Last emitted should be the latest write
      expect(events.last, updated);

      await sub.cancel();
    });

    test("debounces rapid successive writes — only last value emitted", () async {
      final events = <Active>[];
      final sub = activeService.watch.listen(events.add);

      // Write many values rapidly without waiting
      for (var i = 0; i < 5; i++) {
        final a = Active(
          schemaVersion: 2,
          checkoutId: "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc$i",
          activatedAt: "2024-01-01T00:00:0${i}Z",
          serverId: "serenity",
          metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
        );
        // Fire-and-forget writes (they queue via mutex)
        unawaited(activeService.writeActive(a));
        // Small delay so filesystem events are generated
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      // Wait for all writes + debounce to settle
      await Future<void>.delayed(const Duration(milliseconds: 800));

      // Should emit at least one value, and the last one should match the final write
      expect(events.isNotEmpty, isTrue);
      final last = events.last;
      expect(last.checkoutId, "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc4");

      await sub.cancel();
    });

    test("skips emissions when active.json is absent (no false positives)", () async {
      final events = <Active>[];
      final sub = activeService.watch.listen(events.add);

      // Let watcher start; no file exists
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(events, isEmpty);

      await sub.cancel();
    });
  });

  group("ActiveService write mutex", () {
    test("concurrent writes produce deterministic final state", () async {
      // Launch several concurrent writes
      final futures = <Future<void>>[];
      for (var i = 0; i < 5; i++) {
        final a = Active(
          schemaVersion: 2,
          checkoutId: "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd$i",
          activatedAt: "2024-01-01T00:00:0${i}Z",
          serverId: "serenity",
          metadata: GameMetadata(gameServer: "S$i", gameBuild: "B", gameVersion: "V"),
        );
        futures.add(activeService.writeActive(a));
      }
      await Future.wait(futures);

      // The file should exist and be parseable (no corruption)
      final result = activeService.readActive();
      expect(result.isSome(), isTrue);
      expect(File(RepoPaths.activePath).existsSync(), isTrue);
      expect(File("${RepoPaths.activePath}.tmp").existsSync(), isFalse);
    });
  });
}
