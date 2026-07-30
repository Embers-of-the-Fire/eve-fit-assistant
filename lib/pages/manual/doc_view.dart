import "dart:async";

import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/features/deeplink/deeplink.dart";
import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:eve_fit_assistant/pages/manual/breadcrumb.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Renders a manual document: breadcrumb bar, localized title/summary
/// header, and the Markdown body.
class ManualDocView extends ConsumerWidget {
  const ManualDocView({required this.doc, required this.ancestors, super.key});

  /// The document to display.
  final ManualDocEntry doc;

  /// Folder chain containing [doc], from the top level down.
  final List<ManualFolderEntry> ancestors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = context.locale.toString();
    final localization = doc.resolveLocalization(localeCode)?.data;

    if (localization == null) {
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

    final contentAsync = ref.watch(manualContentProvider(localization.contentFile));

    return Column(
      children: [
        ManualBreadcrumb(ancestors: ancestors, currentLabel: localization.title),
        Expanded(
          child: contentAsync.when(
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
                      child: Markdown(
                        data: content,
                        padding: EdgeInsets.zero,
                        softLineBreak: true,
                        styleSheet: markdownDarkStyleSheet,
                        onTapLink: (text, href, title) {
                          if (href == null) return;
                          unawaited(
                            ref
                                .read(appLinkHandlerProvider)
                                .open(context, href, basePath: _docBasePath(doc)),
                          );
                        },
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
          ),
        ),
      ],
    );
  }
}

/// The route path of the folder containing [doc]; relative links inside the
/// document resolve against it.
String _docBasePath(ManualDocEntry doc) {
  final segments = doc.id.split("/")..removeLast();
  return segments.isEmpty ? "/manual" : "/manual/${segments.join("/")}";
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
