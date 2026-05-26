import "dart:async";

import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/bundle/remote_catalog.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

String _computeUpdateKey(IList<RemoteBundleCandidate> recommended) {
  final ids = recommended.map((c) => c.artifact.artifactId).toList()..sort();
  return ids.join(",");
}

String _formatUpdateSummary(BuildContext context, IList<RemoteBundleCandidate> recommended) {
  final first = recommended.first.artifact.artifactId;
  if (recommended.length == 1) {
    return context.l10n.startupBundleUpdateSummaryRecommended(firstId: first);
  }
  return context.l10n.startupBundleUpdateSummaryWithCount(
    firstId: first,
    moreCount: recommended.length - 1,
  );
}

final startupBundleUpdateProvider = FutureProvider<RemoteBundleCatalogState?>((ref) async {
  final setting = ref.read(appSettingServiceProvider);
  if (!setting.remoteContent.enabled) {
    return null;
  }

  final catalog = await ref.read(remoteBundleCatalogManagerProvider.future);
  if (catalog.recommended.isEmpty) {
    return null;
  }

  final updateKey = _computeUpdateKey(catalog.recommended);
  if (updateKey == setting.lastNotifiedBundleUpdateKey) {
    return null;
  }

  return catalog;
});

Future<void> showStartupBundleUpdateDialog(
  BuildContext context,
  IList<RemoteBundleCandidate> recommended, {
  required VoidCallback onPersistPreference,
  required VoidCallback onShowBundleManager,
}) => showDialog<void>(
  context: context,
  builder: (context) => _StartupBundleUpdateDialog(
    recommended: recommended,
    onPersistPreference: onPersistPreference,
    onShowBundleManager: onShowBundleManager,
  ),
);

class _StartupBundleUpdateDialog extends StatefulWidget {
  const _StartupBundleUpdateDialog({
    required this.recommended,
    required this.onPersistPreference,
    required this.onShowBundleManager,
  });

  final IList<RemoteBundleCandidate> recommended;
  final VoidCallback onPersistPreference;
  final VoidCallback onShowBundleManager;

  @override
  State<_StartupBundleUpdateDialog> createState() => _StartupBundleUpdateDialogState();
}

class _StartupBundleUpdateDialogState extends State<_StartupBundleUpdateDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = widget.recommended.length;

    final description = count == 1
        ? l10n.startupBundleUpdateSingleDescription
        : l10n.startupBundleUpdateMultipleDescription(count: count);

    return AppDialog(
      title: l10n.startupBundleUpdateTitle,
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(description, style: context.theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Text(
                      _formatUpdateSummary(context, widget.recommended),
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Theme(
              data: context.theme.copyWith(
                checkboxTheme: context.theme.checkboxTheme.copyWith(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              child: CheckboxListTile(
                value: _dontShowAgain,
                dense: true,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => setState(() => _dontShowAgain = value ?? false),
                title: Text(l10n.dontShowAgain, style: context.theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: _handleClose, child: Text(l10n.close)),
        ElevatedButton(onPressed: _handleShowDetails, child: Text(l10n.showDetails)),
      ],
    );
  }

  void _handleClose() {
    if (_dontShowAgain) {
      widget.onPersistPreference();
    }
    context.nav.pop();
  }

  void _handleShowDetails() {
    if (_dontShowAgain) {
      widget.onPersistPreference();
    }
    context.nav.pop();
    widget.onShowBundleManager();
  }
}

class StartupBundleUpdateGate extends ConsumerStatefulWidget {
  const StartupBundleUpdateGate({
    required this.appRouter,
    required this.child,
    required this.navigatorKey,
    super.key,
  });

  final AppRouter appRouter;
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<StartupBundleUpdateGate> createState() => _StartupBundleUpdateGateState();
}

class _StartupBundleUpdateGateState extends ConsumerState<StartupBundleUpdateGate> {
  bool _didCheck = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCheck) {
      return;
    }
    _didCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_showStartupBundleUpdate());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _showStartupBundleUpdate() async {
    final catalog = await _loadStartupBundleUpdate();
    final navigator = widget.navigatorKey.currentState;
    if (!mounted || navigator == null || !navigator.mounted || catalog == null) {
      return;
    }

    await showStartupBundleUpdateDialog(
      navigator.context,
      catalog.recommended,
      onPersistPreference: () {
        final updateKey = _computeUpdateKey(catalog.recommended);
        ref
            .read(appSettingServiceProvider.notifier)
            .update((setting) => setting.copyWith(lastNotifiedBundleUpdateKey: updateKey));
      },
      onShowBundleManager: () {
        unawaited(widget.appRouter.push(const BundleManagerRoute()));
      },
    );
  }

  Future<RemoteBundleCatalogState?> _loadStartupBundleUpdate() async {
    try {
      return await ref.read(startupBundleUpdateProvider.future);
    } on Object catch (errorValue, stackTrace) {
      error("Failed to check startup bundle updates: $errorValue", stackTrace: stackTrace);
      return null;
    }
  }
}
