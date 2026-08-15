import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:eve_fit_assistant/features/manual/repository/manual_feedback_api.dart";
import "package:eve_fit_assistant/pages/manual/doc_view.dart";
import "package:eve_fit_assistant/pages/manual/feedback_page.dart";
import "package:eve_fit_assistant/pages/manual/folder_view.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

const String _githubSourceBaseUrl =
    "https://github.com/Embers-of-the-Fire/eve-fit-assistant/blob/dev/docs/manual";

@RoutePage()
class ManualNodePage extends ConsumerWidget {
  const ManualNodePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(manualTreeProvider);
    final localeCode = context.locale.toString();

    // The route is registered as `/manual/*`; the matched segments look like
    // ["/", "manual", ...path], so drop the root marker and the "manual"
    // segment to obtain the path-joined id of the node to display.
    final nodePath = context.routeData.route.segments
        .where((segment) => segment != "/")
        .skip(1)
        .join("/");
    final resolution = treeAsync.whenData((root) => resolveManualPath(root, nodePath)).value;

    final title = switch (resolution) {
      ManualFolderResolution(folder: final folder) when folder.id.isNotEmpty =>
        folder.resolveName(localeCode) ?? context.l10n.manualPageTitle,
      ManualDocResolution(doc: final doc) =>
        doc.resolveLocalization(localeCode)?.data.title ?? context.l10n.manualPageTitle,
      _ => context.l10n.manualPageTitle,
    };

    final actions = <Widget>[
      ...?switch (resolution) {
        ManualDocResolution(doc: final doc) => _buildDocActions(context, doc, localeCode),
        _ => null,
      },
      const ManualQuestionAction(),
    ];

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(title), actions: actions),
      body: treeAsync.when(
        data: (_) => switch (resolution) {
          ManualFolderResolution(ancestors: final ancestors, folder: final folder) =>
            ManualFolderView(folder: folder, ancestors: ancestors),
          ManualDocResolution(ancestors: final ancestors, doc: final doc) => ManualDocView(
            doc: doc,
            ancestors: ancestors,
          ),
          _ => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                context.l10n.manualNodeNotFound,
                style: context.theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        },
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

  List<Widget> _buildDocActions(BuildContext context, ManualDocEntry doc, String localeCode) {
    final localization = doc.resolveLocalization(localeCode);
    final sourceUrl = Uri.parse(
      "$_githubSourceBaseUrl/${doc.id}/${localization?.localeCode ?? "en"}.md",
    );

    return [
      IconButton(
        icon: const Icon(Icons.flag_outlined),
        tooltip: context.l10n.manualActionReportTooltip,
        onPressed: () => unawaited(
          context.router.push(
            ManualFeedbackRoute(
              kind: ManualFeedbackKind.report,
              docId: doc.id,
              docTitle: doc.resolveLocalization(localeCode)?.data.title,
            ),
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.code),
        tooltip: context.l10n.manualActionViewSourceTooltip,
        onPressed: () => unawaited(_openUrl(context, sourceUrl)),
      ),
    ];
  }

  Future<void> _openUrl(BuildContext context, Uri uri) async {
    try {
      final didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!didLaunch && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.reportOpenError)));
      }
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.reportOpenError)));
      }
    }
  }
}
