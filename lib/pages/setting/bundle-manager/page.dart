import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/clickable/circle_avatar.dart";
import "package:eve_fit_assistant/components/color.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/datetime.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

part "bundle_detail.dart";
part "bundle_tile.dart";

@RoutePage()
class BundleManagerPage extends ConsumerWidget {
  const BundleManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleRegistry = ref.watch(bundleRegistryManagerProvider);

    return Layout(
      title: context.l10n.bundleManagerPageTitle,
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      child: ListView(
        children: [
          const SizedBox(height: 10),
          if (bundleRegistry.selectedBundleId != null)
            _BundleTile(
              bundle: bundleRegistry.bundles[bundleRegistry.selectedBundleId!]!,
              activated: true,
            ),
          for (final entry in bundleRegistry.bundles.entries.where(
            (k) => k.key != bundleRegistry.selectedBundleId,
          ))
            _BundleTile(bundle: entry.value),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
