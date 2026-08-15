import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

@RoutePage()
class ReportExternalLinksPage extends ConsumerWidget {
  const ReportExternalLinksPage({super.key});

  static const _githubIssuesUrl = "https://github.com/Embers-of-the-Fire/eve-fit-assistant/issues";
  static const _tencentFormUrl = "https://docs.qq.com/form/page/DV0JsUURRU054Y3pY";
  static const _tencentSheetUrl = "https://docs.qq.com/sheet/DV25JV2VxS2J2Q2dj?tab=q1br0o";
  static const _securityEmail = "security@efa-tech.dev";
  static const _securityEmailSubject = "[EFA/Security] Vulnerability Report";
  static const _securityQQ = "3562377918";
  static const _qqOfficial = "1031146601";

  @override
  Widget build(BuildContext context, WidgetRef ref) => Layout(
    title: context.l10n.reportExternalChannelsTitle,
    child: ConfigListView(
      children: [
        const ConfigListTile.space(20),
        ConfigListTile.title(context.l10n.reportSectionGeneral),
        ConfigListTile.item(
          icon: const Icon(Icons.bug_report_outlined),
          title: context.l10n.reportTileGitHub,
          subtitle: context.l10n.reportTileGitHubDescription,
          onTap: () => _openUrl(context, Uri.parse(_githubIssuesUrl)),
        ),
        ConfigListTile.item(
          icon: const Icon(Icons.description_outlined),
          title: context.l10n.reportTileTencentForm,
          subtitle: context.l10n.reportTileTencentFormDescription,
          onTap: () => _openUrl(context, Uri.parse(_tencentFormUrl)),
        ),
        ConfigListTile.item(
          icon: const Icon(Icons.table_chart_outlined),
          title: context.l10n.reportTileTencentSheet,
          subtitle: context.l10n.reportTileTencentSheetDescription,
          onTap: () => _openUrl(context, Uri.parse(_tencentSheetUrl)),
        ),
        ConfigListTile.title(context.l10n.reportSectionCommunity),
        ConfigListTile.item(
          icon: const Icon(Icons.chat_outlined),
          title: context.l10n.reportTileQQOfficial,
          subtitle: context.l10n.reportTileQQOfficialDescription,
          onTap: () => _copyQQ(context, _qqOfficial),
        ),
        ConfigListTile.title(context.l10n.reportSectionSecurity),
        ConfigListTile.item(
          icon: const Icon(Icons.email_outlined),
          title: context.l10n.reportTileSecurityEmail,
          subtitle: context.l10n.reportTileSecurityEmailDescription,
          onTap: () => _openUrl(
            context,
            Uri(
              scheme: "mailto",
              path: _securityEmail,
              queryParameters: {"subject": _securityEmailSubject},
            ),
          ),
        ),
        ConfigListTile.item(
          icon: const Icon(Icons.lock_outlined),
          title: context.l10n.reportTileSecurityQQ,
          subtitle: context.l10n.reportTileSecurityQQDescription,
          onTap: () => _copyQQ(context, _securityQQ),
        ),
      ],
    ),
  );

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

  void _copyQQ(BuildContext context, String qqNumber) {
    unawaited(
      Clipboard.setData(ClipboardData(text: qqNumber))
          .then((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(context.l10n.reportCopyQQSuccess)));
            }
          })
          .catchError((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(context.l10n.reportCopyQQError)));
            }
          }),
    );
  }
}
