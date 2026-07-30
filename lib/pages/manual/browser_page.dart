import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:eve_fit_assistant/pages/manual/folder_view.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class ManualBrowserPage extends ConsumerWidget {
  const ManualBrowserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(manualTreeProvider);

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(context.l10n.manualPageTitle)),
      body: treeAsync.when(
        data: (root) => ManualFolderView(folder: root, ancestors: const []),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 56, color: context.theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  context.l10n.manualContentLoadError,
                  style: context.theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(manualTreeProvider),
                  child: Text(context.l10n.manualContentLoadRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
