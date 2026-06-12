import "dart:async";

import "package:eve_fit_assistant/components/dialog/announcement_dialog.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:eve_fit_assistant/features/documents/remote_sync.dart";
import "package:eve_fit_assistant/features/documents/repository.dart";
import "package:eve_fit_assistant/features/documents/storage.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

final startupAvailableUpdateProvider = FutureProvider<DocumentRecord?>((Ref ref) async {
  final setting = ref.read(appSettingServiceProvider);
  if (!setting.remoteContent.enabled) {
    return null;
  }

  try {
    await ref.read(remoteDocumentSyncServiceProvider).sync().timeout(
      const Duration(seconds: 5),
    );
  } on TimeoutException {
    // Proceed with whatever data is available
  }

  final appVer = await ref.read(appVersionProvider.future);
  final records = await ref.read(documentFeedProvider(DocumentFeedKind.version).future);

  final candidates = records
      .where((DocumentRecord r) => r.appVer != null && compareAppVersions(r.appVer!, appVer) > 0)
      .toList();
  if (candidates.isEmpty) {
    return null;
  }

  candidates.sort(
    (DocumentRecord a, DocumentRecord b) => compareAppVersions(b.appVer!, a.appVer!),
  );
  final latest = candidates.first;

  if (latest.appVer == DocumentStorage.notifiedAvailableVersion) {
    return null;
  }
  return latest;
});

class AvailableUpdateGate extends ConsumerStatefulWidget {
  const AvailableUpdateGate({
    required this.appRouter,
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final AppRouter appRouter;
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<AvailableUpdateGate> createState() => _AvailableUpdateGateState();
}

class _AvailableUpdateGateState extends ConsumerState<AvailableUpdateGate> {
  bool _didCheck = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCheck) {
      return;
    }
    _didCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showAvailableUpdate());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _showAvailableUpdate() async {
    final entry = await _loadAvailableUpdate();
    final navigator = widget.navigatorKey.currentState;
    if (!mounted || navigator == null || !navigator.mounted || entry == null) {
      return;
    }

    await showAnnouncementDialog(
      navigator.context,
      title: context.l10n.availableUpdateDialogTitle(version: entry.appVer ?? ""),
      informationText: context.l10n.availableUpdateDialogSummary,
      barrierDismissible: false,
      onShowDetail: () async {
        DocumentStorage.setNotifiedAvailableVersion(entry.appVer!);
        await widget.appRouter.push(const VersionRoute());
      },
      onPersistPreference: ({required bool dontShowAgain}) {
        if (dontShowAgain) {
          DocumentStorage.setNotifiedAvailableVersion(entry.appVer!);
        }
      },
    );
  }

  Future<DocumentRecord?> _loadAvailableUpdate() async {
    try {
      return await ref.read(startupAvailableUpdateProvider.future);
    } catch (errorValue, stackTrace) {
      error("Failed to check for available update: $errorValue", stackTrace: stackTrace);
      return null;
    }
  }
}
