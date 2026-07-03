import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "announcement_state_notifier.g.dart";

@riverpodSingleton
class AnnouncementStateService extends _$AnnouncementStateService {
  @override
  AnnouncementState build() => AnnouncementStateStore.state;

  void markRead(String id) {
    AnnouncementStateStore.markRead(id);
    state = AnnouncementStateStore.state;
  }

  void markAllRead(Iterable<String> ids) {
    AnnouncementStateStore.markAllRead(ids);
    state = AnnouncementStateStore.state;
  }

  void markUnread(Iterable<String> ids) {
    AnnouncementStateStore.markUnread(ids);
    state = AnnouncementStateStore.state;
  }

  void dismiss(String id) {
    AnnouncementStateStore.dismiss(id);
    state = AnnouncementStateStore.state;
  }

  void acknowledgeVersion(String version) {
    AnnouncementStateStore.setLastSeenAppVersion(version);
    state = AnnouncementStateStore.state;
  }

  void acknowledgeRelease(String releaseId) {
    AnnouncementStateStore.acknowledgeRelease(releaseId);
    state = AnnouncementStateStore.state;
  }

  void clearReleaseAcknowledgment() {
    AnnouncementStateStore.clearReleaseAcknowledgment();
    state = AnnouncementStateStore.state;
  }
}
