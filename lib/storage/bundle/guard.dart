import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

Future<bool> ensureUsableBundle(BuildContext context, WidgetRef ref) async {
  final state = ref.read(bundleServiceProvider);
  if (state.isLoaded) {
    return true;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.bundleAccessRequiredTitle),
      content: Text(_bundleAccessDescription(context, state)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            unawaited(context.router.push(const BundleManagerRoute()));
          },
          child: Text(context.l10n.bundleAccessManageAction),
        ),
      ],
    ),
  );

  return false;
}

String describeBundleAccessState(BuildContext context, CurrentBundleStatus state) =>
    _bundleAccessDescription(context, state);

String _bundleAccessDescription(BuildContext context, CurrentBundleStatus state) => state.when(
  notSelected: () => context.l10n.bundleAccessNotSelectedDescription,
  initializing: (_) => context.l10n.bundleAccessLoadingDescription,
  error: (_) => context.l10n.bundleAccessInvalidDescription,
  loaded: (_) => context.l10n.bundleAccessReadyDescription,
);
