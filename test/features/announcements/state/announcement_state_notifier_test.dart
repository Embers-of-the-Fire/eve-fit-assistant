@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_notifier.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/storage/fs/file_doc_store.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync("efa_state_notifier_test_");
    PathProvider.documentsPath = tempDir.path;
    PathProvider.tempPath = tempDir.path;
    PathProvider.appSupportPath = tempDir.path;
    PathProvider.cachesPath = tempDir.path;
  });

  late AnnouncementStateStore store;
  late ProviderContainer container;

  setUp(() async {
    store = AnnouncementStateStore(store: FileDocStore(p.join(tempDir.path, "settings")));
    await store.init();
    container = ProviderContainer(
      overrides: [announcementStateStoreProvider.overrideWithValue(store)],
    );
  });

  tearDown(() => container.dispose());

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  group("AnnouncementStateService", () {
    test("build reads store state correctly", () {
      store.markRead("entry-1");
      final serviceState = container.read(announcementStateServiceProvider);

      expect(serviceState.readIds, contains("entry-1"));
    });

    test("markRead updates state reactively", () {
      final notifier = container.read(announcementStateServiceProvider.notifier);
      notifier.markRead("entry-1");

      final serviceState = container.read(announcementStateServiceProvider);
      expect(serviceState.readIds, contains("entry-1"));
      expect(store.isRead("entry-1"), isTrue);
    });

    test("markAllRead updates state reactively", () {
      final notifier = container.read(announcementStateServiceProvider.notifier);
      notifier.markAllRead(["a", "b", "c"]);

      final serviceState = container.read(announcementStateServiceProvider);
      expect(serviceState.readIds, containsAll(["a", "b", "c"]));
    });

    test("dismiss updates state reactively", () {
      final notifier = container.read(announcementStateServiceProvider.notifier);
      notifier.dismiss("entry-3");

      final serviceState = container.read(announcementStateServiceProvider);
      expect(serviceState.dismissedIds, contains("entry-3"));
      expect(store.isDismissed("entry-3"), isTrue);
    });

    test("pruneStaleIds removes stale ids", () {
      final notifier = container.read(announcementStateServiceProvider.notifier);
      notifier.markRead("keep");
      notifier.markRead("drop");

      notifier.pruneStaleIds(activeIds: {"keep"});

      final serviceState = container.read(announcementStateServiceProvider);
      expect(serviceState.readIds, ["keep"]);
    });

    test("listener is notified on state change", () {
      final changes = <AnnouncementState>[];
      container.listen(announcementStateServiceProvider, (_, next) => changes.add(next));

      container.read(announcementStateServiceProvider.notifier).markRead("entry-x");
      container.read(announcementStateServiceProvider.notifier).dismiss("entry-y");

      expect(changes.length, greaterThanOrEqualTo(2));
      expect(changes.last.readIds, contains("entry-x"));
      expect(changes.last.dismissedIds, contains("entry-y"));
    });
  });
}
