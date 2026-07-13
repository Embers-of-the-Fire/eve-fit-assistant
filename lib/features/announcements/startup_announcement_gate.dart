import "dart:async";

import "package:eve_fit_assistant/components/dialog/announcement_dialog.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/state/state.dart";
import "package:eve_fit_assistant/pages/announcements/detail_page.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class StartupAnnouncementGate extends ConsumerStatefulWidget {
  const StartupAnnouncementGate({required this.appRouter, required this.child, super.key});

  final AppRouter appRouter;
  final Widget child;

  @override
  ConsumerState<StartupAnnouncementGate> createState() => _StartupAnnouncementGateState();
}

class _StartupAnnouncementGateState extends ConsumerState<StartupAnnouncementGate> {
  bool _isShowing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<AnnouncementRecord>>>(
      startupAnnouncementQueueProvider,
      (_, next) => next.whenData((queue) {
        if (queue.isEmpty || _isShowing) return;
        _isShowing = true;
        unawaited(_showQueue(queue));
      }),
    );
    return widget.child;
  }

  Future<void> _showQueue(List<AnnouncementRecord> queue) async {
    try {
      for (final record in queue) {
        if (!mounted) return;
        await _showOne(record);
      }
    } finally {
      if (mounted) {
        _isShowing = false;
      }
    }
  }

  Future<void> _showOne(AnnouncementRecord record) async {
    final body = await _loadBody(record);
    if (!mounted) return;

    await showAnnouncementDialog(
      context,
      navigatorKey: widget.appRouter.navigatorKey,
      title: record.title,
      bodyMarkdown: body,
      informationText: body == null ? record.summary : null,
      onShowDetail: () async {
        ref.read(announcementStateServiceProvider.notifier).markRead(record.id);
        await widget.appRouter.push(AnnouncementFeedRoute(initialRecordId: record.id));
      },
      onPersistPreference: ({required bool dontShowAgain}) {
        ref.read(announcementStateServiceProvider.notifier).markRead(record.id);
        if (dontShowAgain) {
          ref.read(announcementStateServiceProvider.notifier).dismiss(record.id);
        }
      },
    );
  }

  Future<String?> _loadBody(AnnouncementRecord record) async {
    if (record.bodyHash.isEmpty) return null;
    try {
      return await ref.read(announcementBodyProvider(record.bodyHash).future);
    } on Object catch (errorValue, stackTrace) {
      warning(
        "Failed to load startup announcement body ${record.bodyHash}: $errorValue",
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
