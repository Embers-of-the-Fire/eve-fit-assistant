import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:markdown_widget/markdown_widget.dart";

@RoutePage()
class ManualDocPage extends ConsumerWidget {
  const ManualDocPage({required this.docId, super.key});

  /// Path-joined id of the manual document, e.g. `fitting/modules`.
  final String docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(manualTreeProvider);
    final localeCode = context.locale.toString();

    final doc = treeAsync.whenData((root) => root.findDoc(docId)).value;
    final localization = doc?.resolveLocalization(localeCode)?.data;
    final title = localization?.title ?? context.l10n.manualPageTitle;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(title)),
      body: switch ((treeAsync, doc, localization)) {
        (AsyncLoading(), _, _) => const Center(child: CircularProgressIndicator()),
        (AsyncError(), _, _) => _ManualDocError(onRetry: () => ref.invalidate(manualTreeProvider)),
        (_, null, _) || (_, _, null) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              context.l10n.manualDocNotFound,
              style: context.theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => _ManualDocBody(doc: doc!, localization: localization!),
      },
    );
  }
}

class _ManualDocBody extends ConsumerWidget {
  const _ManualDocBody({required this.doc, required this.localization});

  final ManualDocEntry doc;
  final ManualDocLocalization localization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(manualContentProvider(localization.contentFile));

    return contentAsync.when(
      data: (content) {
        if (content == null || content.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                context.l10n.manualDocNotFound,
                style: context.theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 20, left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localization.title, style: context.theme.textTheme.headlineSmall),
                  if (localization.summary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      localization.summary,
                      style: context.theme.textTheme.bodyMedium?.copyWith(
                        color: context.theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 20, bottom: 10, left: 20),
                child: MarkdownWidget(
                  data: content,
                  padding: EdgeInsets.zero,
                  config: markdownDarkConfig,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ManualDocError(
        onRetry: () => ref.invalidate(manualContentProvider(localization.contentFile)),
      ),
    );
  }
}

class _ManualDocError extends StatelessWidget {
  const _ManualDocError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            context.l10n.manualContentLoadError,
            style: context.theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: Text(context.l10n.manualContentLoadRetry)),
        ],
      ),
    ),
  );
}
