import "dart:async";

import "package:eve_fit_assistant/components/dialog/announcement_dialog.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/state/state.dart";
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
  bool _didCheck = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCheck) return;
    _didCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showStartupAnnouncement());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _showStartupAnnouncement() async {
    final record = await _loadStartupAnnouncement();
    if (!mounted || record == null) return;

    await showAnnouncementDialog(
      context,
      title: record.title,
      informationText: record.summary,
      onShowDetail: () async {
        ref.read(announcementStateServiceProvider.notifier).markRead(record.id);
        await widget.appRouter.push(const AnnouncementFeedRoute());
      },
      onPersistPreference: ({required bool dontShowAgain}) {
        ref.read(announcementStateServiceProvider.notifier).markRead(record.id);
        if (dontShowAgain) {
          ref.read(announcementStateServiceProvider.notifier).dismiss(record.id);
        }
      },
    );
  }

  Future<AnnouncementRecord?> _loadStartupAnnouncement() async {
    try {
      return await ref.read(startupAnnouncementProvider.future);
    } catch (errorValue, stackTrace) {
      error("Failed to load startup announcement: $errorValue", stackTrace: stackTrace);
      return null;
    }
  }
}
