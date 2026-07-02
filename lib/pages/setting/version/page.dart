import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart"
    show unreadAnnouncementCountProvider;
import "package:eve_fit_assistant/pages/router.dart"
    show AnnouncementFeedRoute, DeveloperSettingsRoute;
import "package:eve_fit_assistant/storage/repo/models/models.dart" show CheckoutRegistryEntry;
import "package:eve_fit_assistant/storage/repo/providers.dart"
    show activeCheckoutProvider, availableAppReleaseProvider;
import "package:eve_fit_assistant/storage/repo/repo_version.dart" show currentSchemaVersion;
import "package:eve_fit_assistant/storage/setting/setting.dart"
    show appSettingServiceProvider, developerModeProvider;
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:package_info_plus/package_info_plus.dart";

@RoutePage()
class VersionPage extends ConsumerStatefulWidget {
  const VersionPage({super.key});

  @override
  ConsumerState<VersionPage> createState() => _VersionPageState();
}

class _VersionPageState extends ConsumerState<VersionPage> {
  late final Future<PackageInfo> _packageInfoFuture;
  int _versionTapCount = 0;
  Timer? _versionTapResetTimer;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  void dispose() {
    _versionTapResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appSetting = ref.watch(appSettingServiceProvider);
    final developerMode = ref.watch(developerModeProvider);
    final activeCheckout = ref.watch(activeCheckoutProvider).toNullable();
    final appReleaseAsync = ref.watch(availableAppReleaseProvider);
    final unreadCount = ref.watch(unreadAnnouncementCountProvider);

    return Layout(
      title: context.l10n.versionPageTitle,
      child: FutureBuilder<PackageInfo>(
        future: _packageInfoFuture,
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
              if (developerMode)
                Column(
                  children: [
                    _DeveloperSettingsCard(
                      onTap: () => unawaited(context.router.push(const DeveloperSettingsRoute())),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              appReleaseAsync.when(
                data: (option) {
                  final release = option.toNullable();
                  if (release == null) return const SizedBox.shrink();
                  return Column(
                    children: [
                      _UpdateCard(
                        label: context.l10n.versionPageUpdateAvailable(version: release.version),
                        onTap: () {
                          ref
                              .read(availableAppReleaseProvider.notifier)
                              .acknowledge(release.releaseId);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _InfoSection(
                        title: context.l10n.appTitle,
                        rows: [
                          (
                            label: context.l10n.versionPageAppVersion,
                            value: info?.version,
                            onTap: () => _onVersionRowTapped(context),
                          ),
                          (
                            label: context.l10n.versionPageBuildNumber,
                            value: info?.buildNumber,
                            onTap: null,
                          ),
                          (
                            label: context.l10n.versionPagePackageName,
                            value: info?.packageName,
                            onTap: null,
                          ),
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
                            onTap: null,
                          ),
                          (
                            label: context.l10n.versionPageActiveData,
                            value: _activeCheckoutLabel(context, activeCheckout),
                            onTap: null,
                          ),
                          (
                            label: context.l10n.versionPageChannel,
                            value: appSetting.remoteContent.channel,
                            onTap: null,
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
                        (
                          label: context.l10n.versionPageAppVersion,
                          value: info?.version,
                          onTap: () => _onVersionRowTapped(context),
                        ),
                        (
                          label: context.l10n.versionPageBuildNumber,
                          value: info?.buildNumber,
                          onTap: null,
                        ),
                        (
                          label: context.l10n.versionPagePackageName,
                          value: info?.packageName,
                          onTap: null,
                        ),
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
                          onTap: null,
                        ),
                        (
                          label: context.l10n.versionPageActiveData,
                          value: _activeCheckoutLabel(context, activeCheckout),
                          onTap: null,
                        ),
                        (
                          label: context.l10n.versionPageChannel,
                          value: appSetting.remoteContent.channel,
                          onTap: null,
                        ),
                      ],
                      loading: loading,
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              _ReleaseNotesCard(
                unreadCount: unreadCount,
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

  void _onVersionRowTapped(BuildContext context) {
    if (ref.read(appSettingServiceProvider).developerMode) return;

    _versionTapResetTimer?.cancel();
    _versionTapCount++;
    _versionTapResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _versionTapCount = 0);
    });

    if (_versionTapCount >= 5) {
      _versionTapResetTimer?.cancel();
      _versionTapCount = 0;
      unawaited(_showEnableDeveloperModeDialog(context));
    }
  }

  Future<void> _showEnableDeveloperModeDialog(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.developerModeEnableConfirmTitle,
      content: Text(context.l10n.developerModeEnableConfirmDescription),
    );
    if (!confirmed || !context.mounted) return;
    ref
        .read(appSettingServiceProvider.notifier)
        .update((setting) => setting.copyWith(developerMode: true));
  }
}

class _DeveloperSettingsCard extends StatelessWidget {
  const _DeveloperSettingsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.developer_mode, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.versionPageDeveloperSettingsTitle,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
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

class _ReleaseNotesCard extends StatelessWidget {
  const _ReleaseNotesCard({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.new_releases_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.versionPageReleaseNotes,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
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
  final List<({String label, String? value, VoidCallback? onTap})> rows;
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
                        onTap: row.onTap,
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
  const _InfoRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final valueWidget = Text(
      value,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      textAlign: TextAlign.end,
    );
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
            child: onTap != null
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    child: valueWidget,
                  )
                : valueWidget,
          ),
        ],
      ),
    );
  }
}
