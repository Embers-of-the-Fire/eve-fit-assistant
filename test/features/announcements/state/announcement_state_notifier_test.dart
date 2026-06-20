import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_notifier.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
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

  setUp(() {
    AnnouncementStateStore.init();
  });

  tearDownAll(() {
    tempDir.deleteSync(recursive: true);
  });

  group("AnnouncementStateService", () {
    test("build reads store state correctly", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      AnnouncementStateStore.markRead("entry-1");
      final serviceState = container.read(announcementStateServiceProvider);

      expect(serviceState.readIds, contains("entry-1"));
    });

    test("markRead updates state reactively", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(announcementStateServiceProvider.notifier);
      notifier.markRead("entry-1");

      final serviceState = container.read(announcementStateServiceProvider);
      expect(serviceState.readIds, contains("entry-1"));
      expect(AnnouncementStateStore.isRead("entry-1"), isTrue);
    });

    test("markAllRead updates state reactively", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(announcementStateServiceProvider.notifier);
      notifier.markAllRead(["a", "b", "c"]);

      final serviceState = container.read(announcementStateServiceProvider);
      expect(serviceState.readIds, containsAll(["a", "b", "c"]));
    });

    test("dismiss updates state reactively", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(announcementStateServiceProvider.notifier);
      notifier.dismiss("entry-3");

      final serviceState = container.read(announcementStateServiceProvider);
      expect(serviceState.dismissedIds, contains("entry-3"));
      expect(AnnouncementStateStore.isDismissed("entry-3"), isTrue);
    });

    test("acknowledgeVersion updates state reactively", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(announcementStateServiceProvider.notifier);
      notifier.acknowledgeVersion("5.0.0");

      final serviceState = container.read(announcementStateServiceProvider);
      expect(serviceState.lastSeenAppVersion, "5.0.0");
    });

    test("listener is notified on state change", () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

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
