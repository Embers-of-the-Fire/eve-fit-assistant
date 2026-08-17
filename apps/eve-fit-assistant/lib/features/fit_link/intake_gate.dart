import "dart:async";

import "package:efa_fit/efa_fit.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/deeplink/app_link_handler.dart";
import "package:eve_fit_assistant/features/fit_link/native_intake.dart";
import "package:eve_fit_assistant/features/fit_link/providers.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/repo/data_readiness.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/repo_state.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class FitLinkIntakeGate extends ConsumerStatefulWidget {
  const FitLinkIntakeGate({required this.appRouter, required this.child, super.key});

  final AppRouter appRouter;
  final Widget child;

  @override
  ConsumerState<FitLinkIntakeGate> createState() => _FitLinkIntakeGateState();
}

class _FitLinkIntakeGateState extends ConsumerState<FitLinkIntakeGate> {
  bool _consuming = false;
  NativeFitLinkIntake? _nativeIntake;
  late final ProviderSubscription<PendingFitLink?> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual(pendingFitLinkProvider, fireImmediately: true, (_, next) {
      if (next != null) unawaited(_consume(next));
    });
    if (!kIsWeb) {
      _nativeIntake = NativeFitLinkIntake(
        onFitLink: (uri) => ref.read(pendingFitLinkProvider.notifier).setExternal(uri),
        onInternalLink: (uri) => unawaited(_openInternalLink(uri)),
      );
      _nativeIntake!.start();
    }
  }

  @override
  void dispose() {
    _subscription.close();
    unawaited(_nativeIntake?.dispose());
    super.dispose();
  }

  Future<void> _openInternalLink(Uri uri) async {
    if (!mounted) return;
    await ref.read(appLinkHandlerProvider).open(context, uri.toString());
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _consume(PendingFitLink pending) async {
    if (_consuming) return;
    _consuming = true;
    try {
      if (!await _awaitRepoReady()) {
        warning("Fit link dropped: data store is not available");
        return;
      }
      final importer = ref.read(fitLinkImporterProvider);
      final metadata = await switch (pending) {
        BootFitLink(uri: final uri) => importer.importBootUri(uri),
        ExternalFitLink(uri: final uri) => importer.import(uri),
      };
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.fitImportSuccess(fitName: metadata.name))),
      );
      await widget.appRouter.push(FitRoute(fitId: metadata.fitId));
    } on FitLinkNotFoundException {
      debug("Fit link not recognized, dropped");
    } on EfaFitFormatException {
      if (mounted) await _showInvalidDialog();
    } on Object catch (e, st) {
      warning("Fit link import failed: $e", stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(context.l10n.fitImportUnknownError)));
      }
    } finally {
      _consuming = false;
      if (mounted) {
        if (identical(ref.read(pendingFitLinkProvider), pending)) {
          ref.read(pendingFitLinkProvider.notifier).clear();
        }
        final next = ref.read(pendingFitLinkProvider);
        if (next != null) unawaited(_consume(next));
      }
    }
  }

  Future<bool> _awaitRepoReady() async {
    bool isReady(RepoState state) => state is RepoStateActive && state.entry != null;
    final current = ref.read(repoStateProvider);
    if (current is RepoStateError) return false;
    if (!isReady(current)) {
      final completer = Completer<bool>();
      final sub = ref.listenManual(repoStateProvider, (_, next) {
        if (completer.isCompleted) return;
        if (isReady(next)) completer.complete(true);
        if (next is RepoStateError) completer.complete(false);
      });
      try {
        final repoReady = await completer.future.timeout(
          const Duration(minutes: 2),
          onTimeout: () => false,
        );
        if (!repoReady) return false;
      } finally {
        sub.close();
      }
    }
    return _awaitCollectionReady();
  }

  /// The repo being active does not imply the type collection is decoded:
  /// [DataReadinessNotifier] decodes it asynchronously (chunked on the main
  /// event loop on web), so imports must also wait for [DataReadinessReady].
  Future<bool> _awaitCollectionReady() async {
    final current = ref.read(dataReadinessProvider);
    if (current is DataReadinessReady) return true;
    if (current is DataReadinessError) return false;

    final completer = Completer<bool>();
    final sub = ref.listenManual(dataReadinessProvider, (_, next) {
      if (completer.isCompleted) return;
      if (next is DataReadinessReady) completer.complete(true);
      if (next is DataReadinessError) completer.complete(false);
    });
    try {
      return await completer.future.timeout(const Duration(minutes: 2), onTimeout: () => false);
    } finally {
      sub.close();
    }
  }

  Future<void> _showInvalidDialog() => showDialog<void>(
    context: context,
    builder: (context) => AppDialog(
      title: context.l10n.fitLinkInvalidDialogTitle,
      content: Text(context.l10n.fitLinkInvalidDialogDescription),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.close)),
      ],
    ),
  );
}
