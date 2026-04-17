import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/announcement_dialog.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:eve_fit_assistant/features/documents/repository.dart";
import "package:eve_fit_assistant/features/documents/storage.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

final startupAnnouncementProvider = FutureProvider<DocumentRecord?>((Ref ref) async {
  final locale = ref.watch(localeProvider);
  final repository = ref.watch(documentRepositoryProvider);
  final entries = await repository.loadFeed(
    feedKind: DocumentFeedKind.announcement,
    localeCode: locale.name,
  );

  for (final entry in entries) {
    if (entry.kind != DocumentEntryKind.announcement || !entry.startup) {
      continue;
    }
    if (DocumentStorage.isStartupAnnouncementDismissed(entry.id)) {
      continue;
    }
    return entry;
  }
  return null;
});

class StartupAnnouncementGate extends ConsumerStatefulWidget {
  const StartupAnnouncementGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StartupAnnouncementGate> createState() => _StartupAnnouncementGateState();
}

class _StartupAnnouncementGateState extends ConsumerState<StartupAnnouncementGate> {
  bool _didCheckAnnouncement = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCheckAnnouncement) {
      return;
    }

    _didCheckAnnouncement = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showStartupAnnouncement());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _showStartupAnnouncement() async {
    final entry = await _loadStartupAnnouncement();
    if (!mounted || entry == null) {
      return;
    }

    await showAnnouncementDialog(
      context,
      title: entry.title,
      informationText: entry.summary,
      onShowDetail: () async {
        DocumentStorage.saveSelectedDocumentId(DocumentFeedKind.announcement, entry.id);
        await context.router.push(const AnnouncementRoute());
      },
      onPersistPreference: ({required bool dontShowAgain}) {
        if (!dontShowAgain) {
          return;
        }
        DocumentStorage.dismissStartupAnnouncement(entry.id);
      },
    );
  }

  Future<DocumentRecord?> _loadStartupAnnouncement() async {
    try {
      return await ref.read(startupAnnouncementProvider.future);
    } catch (errorValue, stackTrace) {
      error("Failed to load startup announcement: $errorValue", stackTrace: stackTrace);
      return null;
    }
  }
}
