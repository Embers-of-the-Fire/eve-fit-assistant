import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart"
    show availableUpdateProvider;
import "package:eve_fit_assistant/pages/router.dart" show AnnouncementFeedRoute;
import "package:eve_fit_assistant/storage/repo/models/models.dart" show CheckoutRegistryEntry;
import "package:eve_fit_assistant/storage/repo/providers.dart" show activeCheckoutProvider;
import "package:eve_fit_assistant/storage/repo/repo_version.dart" show currentSchemaVersion;
import "package:eve_fit_assistant/storage/setting/setting.dart" show appSettingServiceProvider;
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:package_info_plus/package_info_plus.dart";

@RoutePage()
class VersionPage extends ConsumerWidget {
  const VersionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSetting = ref.watch(appSettingServiceProvider);
    final activeCheckout = ref.watch(activeCheckoutProvider).toNullable();
    final availableUpdate = ref.watch(availableUpdateProvider);

    return Layout(
      title: context.l10n.versionPageTitle,
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          return ListView(
            children: [
              ConfigListTile.title(context.l10n.appTitle),
              _InfoRow(
                label: context.l10n.versionPageAppVersion,
                value: info?.version ?? context.l10n.loading,
              ),
              _InfoRow(
                label: context.l10n.versionPageBuildNumber,
                value: info?.buildNumber ?? context.l10n.loading,
              ),
              _InfoRow(
                label: context.l10n.versionPagePackageName,
                value: info?.packageName ?? context.l10n.loading,
              ),
              ConfigListTile.title(context.l10n.storageDataManagementTitle),
              _InfoRow(
                label: context.l10n.versionPageSchemaVersion,
                value: currentSchemaVersion.toString(),
              ),
              _InfoRow(
                label: context.l10n.versionPageActiveData,
                value: _activeCheckoutLabel(context, activeCheckout),
              ),
              _InfoRow(
                label: context.l10n.versionPageChannel,
                value: appSetting.remoteContent.channel,
              ),
              if (availableUpdate != null)
                _UpdateNotice(
                  label: context.l10n.versionPageUpdateAvailable(
                    version: availableUpdate.appVersion ?? "",
                  ),
                  onTap: () => unawaited(context.router.push(const AnnouncementFeedRoute())),
                ),
            ],
          );
        },
      ),
    );
  }

  String _activeCheckoutLabel(BuildContext context, CheckoutRegistryEntry? entry) {
    if (entry == null) return context.l10n.versionPageNotApplicable;
    final localeName = context.locale.toString();
    final localizedName = entry.name[localeName];
    if (localizedName != null && localizedName.isNotEmpty) return localizedName;
    return entry.serverId;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ColoredBox(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value, style: theme.textTheme.bodyMedium, textAlign: TextAlign.end),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateNotice extends StatelessWidget {
  const _UpdateNotice({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ColoredBox(
      color: theme.colorScheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.system_update_alt),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
