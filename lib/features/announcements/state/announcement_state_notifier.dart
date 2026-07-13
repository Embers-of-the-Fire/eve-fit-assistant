import "package:eve_fit_assistant/features/announcements/models/announcement_state.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "announcement_state_notifier.g.dart";

/// Singleton store provider. The store is created lazily and must be
/// initialized via [AnnouncementStateStore.init] before any reads. The
/// production wiring does this in `initSingletons()` (see init.dart) and
/// overrides this provider with the initialized instance.
@riverpodSingleton
AnnouncementStateStore announcementStateStore(Ref ref) {
  throw UnimplementedError(
    "announcementStateStoreProvider must be overridden with an initialized store "
    "before use. Call AnnouncementStateStore.init() during app startup.",
  );
}

@riverpodSingleton
class AnnouncementStateService extends _$AnnouncementStateService {
  @override
  AnnouncementState build() => ref.watch(announcementStateStoreProvider).state;

  void markRead(String id) {
    ref.read(announcementStateStoreProvider).markRead(id);
    state = ref.read(announcementStateStoreProvider).state;
  }

  void markAllRead(Iterable<String> ids) {
    ref.read(announcementStateStoreProvider).markAllRead(ids);
    state = ref.read(announcementStateStoreProvider).state;
  }

  void markUnread(Iterable<String> ids) {
    ref.read(announcementStateStoreProvider).markUnread(ids);
    state = ref.read(announcementStateStoreProvider).state;
  }

  void dismiss(String id) {
    ref.read(announcementStateStoreProvider).dismiss(id);
    state = ref.read(announcementStateStoreProvider).state;
  }

  /// Remove IDs not in [activeIds] from read/dismissed sets. Call after a
  /// successful feed sync so state stays bounded.
  void pruneStaleIds({required Set<String> activeIds}) {
    ref.read(announcementStateStoreProvider).pruneStaleIds(activeIds: activeIds);
    state = ref.read(announcementStateStoreProvider).state;
  }
}
