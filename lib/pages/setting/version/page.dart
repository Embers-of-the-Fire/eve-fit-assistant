import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart"
    show availableUpdateProvider;
import "package:eve_fit_assistant/pages/router.dart" show AnnouncementFeedRoute;
import "package:eve_fit_assistant/storage/repo/models/models.dart" show CheckoutRegistryEntry;
import "package:eve_fit_assistant/storage/repo/providers.dart" show activeCheckoutProvider;
import "package:eve_fit_assistant/storage/repo/repo_version.dart" show currentSchemaVersion;
import "package:eve_fit_assistant/storage/setting/setting.dart" show appSettingServiceProvider;
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/screen.dart";
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
          final loading = info == null;
          final isWide = screenColumnTarget(context) != ScreenColumnTarget.one;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              _AppHeader(
                appName: info?.appName ?? context.l10n.appTitle,
                version: info?.version ?? context.l10n.loading,
                buildNumber: info?.buildNumber ?? context.l10n.loading,
                loading: loading,
              ),
              const SizedBox(height: 24),
              if (availableUpdate != null)
                _UpdateCard(
                  label: context.l10n.versionPageUpdateAvailable(
                    version: availableUpdate.appVersion ?? "",
                  ),
                  onTap: () => unawaited(context.router.push(const AnnouncementFeedRoute())),
                ),
              if (availableUpdate != null) const SizedBox(height: 24),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _InfoSection(
                        title: context.l10n.appTitle,
                        rows: [
                          (label: context.l10n.versionPageAppVersion, value: info?.version),
                          (label: context.l10n.versionPageBuildNumber, value: info?.buildNumber),
                          (label: context.l10n.versionPagePackageName, value: info?.packageName),
                        ],
                        loading: loading,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _InfoSection(
                        title: context.l10n.storageDataManagementTitle,
                        rows: [
                          (
                            label: context.l10n.versionPageSchemaVersion,
                            value: currentSchemaVersion.toString(),
                          ),
                          (
                            label: context.l10n.versionPageActiveData,
                            value: _activeCheckoutLabel(context, activeCheckout),
                          ),
                          (
                            label: context.l10n.versionPageChannel,
                            value: appSetting.remoteContent.channel,
                          ),
                        ],
                        loading: loading,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _InfoSection(
                      title: context.l10n.appTitle,
                      rows: [
                        (label: context.l10n.versionPageAppVersion, value: info?.version),
                        (label: context.l10n.versionPageBuildNumber, value: info?.buildNumber),
                        (label: context.l10n.versionPagePackageName, value: info?.packageName),
                      ],
                      loading: loading,
                    ),
                    const SizedBox(height: 16),
                    _InfoSection(
                      title: context.l10n.storageDataManagementTitle,
                      rows: [
                        (
                          label: context.l10n.versionPageSchemaVersion,
                          value: currentSchemaVersion.toString(),
                        ),
                        (
                          label: context.l10n.versionPageActiveData,
                          value: _activeCheckoutLabel(context, activeCheckout),
                        ),
                        (
                          label: context.l10n.versionPageChannel,
                          value: appSetting.remoteContent.channel,
                        ),
                      ],
                      loading: loading,
                    ),
                  ],
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

class _AppHeader extends StatelessWidget {
  const _AppHeader({
    required this.appName,
    required this.version,
    required this.buildNumber,
    required this.loading,
  });

  final String appName;
  final String version;
  final String buildNumber;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final target = screenColumnTarget(context);
    final isWide = target != ScreenColumnTarget.one;

    final symbol = loading
        ? SizedBox(
            width: 72,
            height: 72,
            child: CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary),
          )
        : const Image(image: AssetImage("logo/logo.png"), width: 72, height: 72);

    final nameText = Text(
      appName,
      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    );

    final versionText = Text(
      isWide
          ? context.l10n.versionPageVersionWithBuild(version: version, buildNumber: buildNumber)
          : "v$version",
      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );

    final buildText = Text(
      context.l10n.versionPageBuildLabel(buildNumber: buildNumber),
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );

    if (isWide) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            symbol,
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [nameText, const SizedBox(height: 4), versionText],
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        children: [
          symbol,
          const SizedBox(height: 16),
          nameText,
          const SizedBox(height: 4),
          versionText,
          if (!loading) ...[const SizedBox(height: 2), buildText],
        ],
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Card.filled(
      color: theme.colorScheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.system_update_alt, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows, required this.loading});

  final String title;
  final List<({String label, String? value})> rows;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final (index, row) in rows.indexed)
                  Column(
                    children: [
                      if (index > 0) const Divider(height: 16),
                      _InfoRow(
                        label: row.label,
                        value: loading ? context.l10n.loading : row.value!,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            flex: 2,
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
