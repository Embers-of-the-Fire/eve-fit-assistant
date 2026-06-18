import "dart:async";

import "package:eve_fit_assistant/components/dialog/announcement_dialog.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/state/state.dart";
import "package:eve_fit_assistant/main.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class AvailableUpdateGate extends ConsumerStatefulWidget {
  const AvailableUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AvailableUpdateGate> createState() => _AvailableUpdateGateState();
}

class _AvailableUpdateGateState extends ConsumerState<AvailableUpdateGate> {
  bool _didCheck = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCheck) return;
    _didCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showAvailableUpdate());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _showAvailableUpdate() async {
    final record = await _loadAvailableUpdate();
    if (!mounted || record == null) return;

    await showAnnouncementDialog(
      context,
      navigatorKey: MyApp.navigatorKey,
      title: context.l10n.availableUpdateDialogTitle(version: record.appVersion ?? ""),
      informationText: record.summary,
      barrierDismissible: false,
      onPersistPreference: ({required bool dontShowAgain}) {
        if (dontShowAgain && record.appVersion != null) {
          ref
              .read(announcementStateServiceProvider.notifier)
              .acknowledgeVersion(record.appVersion!);
        }
      },
    );
  }

  Future<AnnouncementRecord?> _loadAvailableUpdate() async {
    try {
      return ref.read(availableUpdateProvider);
    } catch (errorValue, stackTrace) {
      error("Failed to check for available update: $errorValue", stackTrace: stackTrace);
      return null;
    }
  }
}
