import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/clickable/circle_avatar.dart";
import "package:eve_fit_assistant/components/color.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/bundle/impact.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/remote_catalog.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/verification.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/datetime.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

part "bundle_detail.dart";
part "bundle_tile.dart";
part "impact_warning.dart";
part "remote_bundle_selection.dart";

Future<void> _importRemoteBundle(
  BuildContext context,
  WidgetRef ref,
  RemoteBundleArtifact artifact,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: context.l10n.bundleRemoteImportConfirmTitle,
    content: Text(
      context.l10n.bundleRemoteImportConfirmDescription(artifactId: artifact.artifactId),
    ),
  );
  if (!confirmed || !context.mounted) {
    return;
  }

  await ref
      .read(bundleManagerProvider.notifier)
      .addRemoteBundle(
        artifact,
        confirmIncrementalImpact: (report) => confirmBundleImpactWarning(context, ref, report),
        confirmOverwrite: () async {
          if (!context.mounted) return false;
          return showConfirmDialog(context, title: context.l10n.bundleImportOverwriteTitle);
        },
      );
  ref.invalidate(remoteBundleCatalogManagerProvider);
  if (!context.mounted) {
    return;
  }
  ref
      .read(bundleManagerProvider)
      .whenOrNull(
        error: (error, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.bundleRemoteImportFailed(message: error.toString()))),
        ),
        data: (_) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.bundleRemoteImportSucceeded))),
      );
}

@RoutePage()
class BundleManagerPage extends ConsumerWidget {
  const BundleManagerPage({super.key});

  Future<void> _importBundleArchive(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles();
    if (!context.mounted || result == null) return;

    final selected = result.xFiles.first;
    info("Selected file: ${selected.name}");
    await ref
        .read(bundleManagerProvider.notifier)
        .addBundle(
          selected.path,
          confirmIncrementalImpact: (report) => confirmBundleImpactWarning(context, ref, report),
          confirmOverwrite: () async {
            if (!context.mounted) return false;
            return showConfirmDialog(context, title: context.l10n.bundleImportOverwriteTitle);
          },
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleRegistry = ref.watch(bundleRegistryManagerProvider);
    final bundleState = ref.watch(bundleServiceProvider);
    final remoteCatalog = ref.watch(remoteBundleCatalogManagerProvider);
    final activeBundleId = ref.watch(currentBundleProvider)?.bundleId;
    final pendingBundleId = bundleState.isInitializing
        ? ref.read(bundleServiceProvider.notifier).pendingBundleId ?? bundleState.bundleId
        : null;
    final activeBundle = activeBundleId == null ? null : bundleRegistry.bundles[activeBundleId];

    return Layout(
      title: context.l10n.bundleManagerPageTitle,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _importBundleArchive(context, ref),
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      child: ListView(
        children: [
          const SizedBox(height: 10),
          _BundleStatusCard(
            bundleCount: bundleRegistry.bundles.length,
            activeBundleId: activeBundleId,
            pendingBundleId: pendingBundleId,
            state: bundleState,
            onImportPressed: () => _importBundleArchive(context, ref),
          ),
          _RemoteBundleSection(
            state: remoteCatalog,
            onRefreshPressed: () => ref.invalidate(remoteBundleCatalogManagerProvider),
          ),
          if (activeBundle != null)
            _BundleTile(
              bundle: activeBundle,
              activated: true,
              pending: pendingBundleId == activeBundle.bundleId,
            ),
          for (final entry in bundleRegistry.bundles.entries.where(
            (entry) => entry.key != activeBundle?.bundleId,
          ))
            _BundleTile(bundle: entry.value, pending: pendingBundleId == entry.key),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _BundleStatusCard extends StatelessWidget {
  const _BundleStatusCard({
    required this.bundleCount,
    required this.activeBundleId,
    required this.pendingBundleId,
    required this.state,
    required this.onImportPressed,
  });

  final int bundleCount;
  final String? activeBundleId;
  final String? pendingBundleId;
  final CurrentBundleStatus state;
  final VoidCallback onImportPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = theme.colorScheme;
    final scopeDetails = <String>[
      context.l10n.bundleManagerAlphaScope,
      context.l10n.bundleManagerImportSelectionBehavior,
    ];
    final info = bundleCount == 0
        ? (
            icon: Icons.archive_outlined,
            color: colorScheme.primary,
            title: context.l10n.bundleManagerSetupTitle,
            description: context.l10n.bundleManagerSetupDescription,
            details: scopeDetails,
          )
        : state.when(
            notSelected: () => (
              icon: Icons.archive_outlined,
              color: colorScheme.secondary,
              title: context.l10n.bundleManagerSelectionTitle,
              description: context.l10n.bundleManagerSelectionDescription,
              details: scopeDetails,
            ),
            initializing: (bundleId) => (
              icon: Icons.sync,
              color: colorScheme.primary,
              title: context.l10n.bundleManagerLoadingTitle,
              description: context.l10n.bundleManagerLoadingDescription(bundleId: bundleId),
              details: [
                ...scopeDetails,
                if (activeBundleId != null)
                  context.l10n.bundleManagerReadyDescription(bundleId: activeBundleId!),
              ],
            ),
            error: (errors) => (
              icon: Icons.error_outline,
              color: colorScheme.error,
              title: context.l10n.bundleManagerInvalidTitle,
              description: context.l10n.bundleManagerInvalidDescription,
              details: [
                ...scopeDetails,
                ...errors.map((error) => _formatBundleError(context, error)),
              ],
            ),
            loaded: (data) => (
              icon: Icons.check_circle_outline,
              color: colorGreen,
              title: context.l10n.bundleManagerReadyTitle,
              description: context.l10n.bundleManagerReadyDescription(bundleId: data.bundleId),
              details: scopeDetails,
            ),
          );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(info.icon, color: info.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(info.description, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            if (info.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final detail in info.details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(detail, style: theme.textTheme.bodySmall),
                ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onImportPressed,
              icon: const Icon(Icons.upload_file),
              label: Text(context.l10n.bundleManagerImportAction),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBundleError(BuildContext context, BundleValidationError error) => error.when(
    missingPath: (path) => context.l10n.bundleManagerErrorMissingPath(path: path),
    expectFile: (fileName) => context.l10n.bundleManagerErrorExpectFile(fileName: fileName),
    expectDirectory: (dirName) => context.l10n.bundleManagerErrorExpectDirectory(dirName: dirName),
    badDescriptor: (_) => context.l10n.bundleManagerErrorBadDescriptor,
    badPatch: (reason) => context.l10n.bundleManagerErrorBadPatch(reason: reason),
  );
}

class _RemoteBundleSection extends ConsumerWidget {
  const _RemoteBundleSection({required this.state, required this.onRefreshPressed});

  final AsyncValue<RemoteBundleCatalogState> state;
  final VoidCallback onRefreshPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = switch (state) {
      AsyncData(value: final data) => data,
      _ => null,
    };
    if (value != null && !value.enabled) {
      return const SizedBox.shrink();
    }

    final theme = context.theme;
    final firstRecommended = value?.recommended.firstOrNull;
    final summary = _remoteBundleSummary(context, state, value);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_download_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.bundleRemoteSectionTitle,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(context.l10n.bundleRemoteSectionDescription),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.bundleRemoteRefreshAction,
                  onPressed: state.isLoading ? null : onRefreshPressed,
                  icon: state.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            if (value?.error != null) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.bundleRemoteError(message: value!.error!),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (summary != null) ...[
              const SizedBox(height: 8),
              Text(summary, style: theme.textTheme.bodySmall),
            ],
            if (value != null && value.error == null && value.candidates.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RemoteBundleCounts(state: value),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: value == null
                      ? null
                      : () => context.router.push(const RemoteBundleSelectionRoute()),
                  icon: const Icon(Icons.manage_search_outlined),
                  label: Text(context.l10n.bundleRemoteReviewAction),
                ),
                if (firstRecommended != null)
                  FilledButton.icon(
                    onPressed: () => _importRemoteBundle(context, ref, firstRecommended.artifact),
                    icon: const Icon(Icons.download),
                    label: Text(context.l10n.bundleRemoteDownloadRecommendedAction),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _remoteBundleSummary(
    BuildContext context,
    AsyncValue<RemoteBundleCatalogState> asyncState,
    RemoteBundleCatalogState? state,
  ) {
    final providerError = switch (asyncState) {
      AsyncError(error: final error) => error,
      _ => null,
    };
    if (providerError != null) {
      return context.l10n.bundleRemoteError(message: providerError.toString());
    }
    if (asyncState.isLoading) {
      return context.l10n.bundleRemoteChecking;
    }
    if (state == null || state.error != null) {
      return null;
    }
    if (!state.catalogAvailable) {
      return context.l10n.bundleRemoteCatalogMissing;
    }
    if (state.candidates.isEmpty) {
      return context.l10n.bundleRemoteCatalogEmpty;
    }
    final firstRecommended = state.recommended.firstOrNull;
    if (firstRecommended != null) {
      return _formatRemoteCandidateStatus(
        context,
        firstRecommended,
        currentAppVersion: state.appVersion,
      );
    }
    if (state.importable.isNotEmpty) {
      return context.l10n.bundleRemoteAlternativesOnly;
    }
    if (state.installed.isNotEmpty) {
      return context.l10n.bundleRemoteCurrent;
    }
    final firstUnavailable = state.unavailable.firstOrNull;
    if (firstUnavailable != null) {
      return _formatRemoteCandidateStatus(
        context,
        firstUnavailable,
        currentAppVersion: state.appVersion,
      );
    }
    return context.l10n.bundleRemoteNoImportable;
  }
}

class _RemoteBundleCounts extends StatelessWidget {
  const _RemoteBundleCounts({required this.state});

  final RemoteBundleCatalogState state;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _RemoteBundleCountChip(
        label: context.l10n.bundleRemoteRecommendedCount(count: state.recommended.length),
        icon: Icons.auto_awesome_outlined,
      ),
      _RemoteBundleCountChip(
        label: context.l10n.bundleRemoteAvailableCount(count: state.available.length),
        icon: Icons.download_outlined,
      ),
      _RemoteBundleCountChip(
        label: context.l10n.bundleRemoteInstalledCount(count: state.installed.length),
        icon: Icons.verified_outlined,
      ),
      _RemoteBundleCountChip(
        label: context.l10n.bundleRemoteUnavailableCount(count: state.unavailable.length),
        icon: Icons.block_outlined,
      ),
    ],
  );
}

class _RemoteBundleCountChip extends StatelessWidget {
  const _RemoteBundleCountChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 16), label: Text(label), visualDensity: VisualDensity.compact);
}

String _formatRemoteCandidateStatus(
  BuildContext context,
  RemoteBundleCandidate candidate, {
  required String? currentAppVersion,
}) {
  final artifact = candidate.artifact;
  return switch (candidate.state) {
    RemoteBundleCandidateState.recommended => switch (candidate.recommendation) {
      RemoteBundleCandidateRecommendation.incrementalUpdate =>
        context.l10n.bundleRemoteRecommendationIncremental(bundleId: artifact.bundleId),
      RemoteBundleCandidateRecommendation.fullInstall =>
        context.l10n.bundleRemoteRecommendationFullInstall(bundleId: artifact.bundleId),
      RemoteBundleCandidateRecommendation.fullReplacement =>
        context.l10n.bundleRemoteRecommendationFullReplacement(bundleId: artifact.bundleId),
      null => context.l10n.bundleRemoteRecommendedFallback,
    },
    RemoteBundleCandidateState.available => context.l10n.bundleRemoteAvailableDescription,
    RemoteBundleCandidateState.installed => context.l10n.bundleRemoteInstalledDescription,
    RemoteBundleCandidateState.unavailable => _formatRemoteCandidateUnavailableReason(
      context,
      candidate,
      currentAppVersion: currentAppVersion,
    ),
  };
}

String _formatRemoteCandidateUnavailableReason(
  BuildContext context,
  RemoteBundleCandidate candidate, {
  required String? currentAppVersion,
}) {
  final artifact = candidate.artifact;
  return switch (candidate.unavailableReason) {
    RemoteBundleCandidateUnavailableReason.appVersionMismatch =>
      context.l10n.bundleRemoteUnavailableAppVersion(
        requiredVersion: artifact.appVersion,
        currentVersion: currentAppVersion ?? context.l10n.bundleRemoteUnknownAppVersion,
      ),
    RemoteBundleCandidateUnavailableReason.missingIncrementalMetadata =>
      context.l10n.bundleRemoteUnavailableMissingIncrementalMetadata,
    RemoteBundleCandidateUnavailableReason.baseBundleNotInstalled =>
      context.l10n.bundleRemoteUnavailableBaseNotInstalled(
        bundleId: artifact.baseBundleId ?? artifact.bundleId,
      ),
    RemoteBundleCandidateUnavailableReason.installedManifestMissing =>
      context.l10n.bundleRemoteUnavailableInstalledManifestMissing,
    RemoteBundleCandidateUnavailableReason.baseManifestMismatch =>
      context.l10n.bundleRemoteUnavailableBaseManifestMismatch,
    null => context.l10n.bundleRemoteUnavailableUnknown,
  };
}

class _RemoteBundleArtifactTile extends StatelessWidget {
  const _RemoteBundleArtifactTile({
    required this.candidate,
    required this.currentAppVersion,
    required this.onImportPressed,
  });

  final RemoteBundleCandidate candidate;
  final String? currentAppVersion;
  final VoidCallback onImportPressed;

  @override
  Widget build(BuildContext context) {
    final artifact = candidate.artifact;
    final theme = context.theme;
    final variant = artifact.isIncremental
        ? context.l10n.bundleManagerDetailVariantIncremental
        : context.l10n.bundleManagerDetailVariantFull;
    final status = _formatRemoteCandidateStatus(
      context,
      candidate,
      currentAppVersion: currentAppVersion,
    );
    final canShowAction = candidate.canImport && MediaQuery.sizeOf(context).width >= 420;
    final generatedAt = yMMMMdHmsLocalized(context).format(artifact.generatedAt.toLocal());
    final metadata = <String>[
      context.l10n.bundleRemoteArtifactSize(size: _formatByteSize(artifact.artifactSize)),
      context.l10n.bundleRemoteArtifactGenerated(time: generatedAt),
      if (artifact.baseBundleId != null)
        context.l10n.bundleRemoteArtifactBaseBundle(bundleId: artifact.baseBundleId!),
      if (artifact.baseManifestHash != null)
        context.l10n.bundleRemoteArtifactBaseManifest(hash: _shortHash(artifact.baseManifestHash!)),
    ];
    final content = Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(
          _remoteCandidateIcon(candidate),
          color: _remoteCandidateColor(context, candidate),
        ),
        title: Text(
          artifact.artifactId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              context.l10n.bundleRemoteArtifactDescription(
                variant: variant,
                bundleId: artifact.bundleId,
                gameBuild: artifact.gameBuild,
                gameServer: artifact.gameServer,
              ),
            ),
            const SizedBox(height: 2),
            Text(status, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [for (final item in metadata) _RemoteBundleMetadataChip(label: item)],
            ),
            if (candidate.canImport) ...[
              const SizedBox(height: 8),
              Text(context.l10n.bundleRemoteImportBehaviorHint, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        trailing: canShowAction
            ? FilledButton.tonalIcon(
                onPressed: onImportPressed,
                icon: const Icon(Icons.download),
                label: Text(context.l10n.bundleRemoteDownloadImportAction),
              )
            : null,
      ),
    );
    if (!candidate.canImport || canShowAction) {
      return content;
    }
    return Column(
      children: [
        content,
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onImportPressed,
              icon: const Icon(Icons.download),
              label: Text(context.l10n.bundleRemoteDownloadImportAction),
            ),
          ),
        ),
      ],
    );
  }
}

class _RemoteBundleMetadataChip extends StatelessWidget {
  const _RemoteBundleMetadataChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(label, style: context.theme.textTheme.labelSmall),
    ),
  );
}

IconData _remoteCandidateIcon(RemoteBundleCandidate candidate) => switch (candidate.state) {
  RemoteBundleCandidateState.recommended => Icons.auto_awesome_outlined,
  RemoteBundleCandidateState.available =>
    candidate.artifact.isIncremental ? Icons.update : Icons.archive_outlined,
  RemoteBundleCandidateState.installed => Icons.verified_outlined,
  RemoteBundleCandidateState.unavailable => Icons.block_outlined,
};

Color _remoteCandidateColor(BuildContext context, RemoteBundleCandidate candidate) =>
    switch (candidate.state) {
      RemoteBundleCandidateState.recommended => context.theme.colorScheme.primary,
      RemoteBundleCandidateState.available => context.theme.colorScheme.secondary,
      RemoteBundleCandidateState.installed => colorGreen,
      RemoteBundleCandidateState.unavailable => context.theme.colorScheme.error,
    };

String _formatByteSize(int bytes) {
  const units = ["B", "KiB", "MiB", "GiB"];
  double size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex += 1;
  }
  if (unitIndex == 0) {
    return "$bytes ${units[unitIndex]}";
  }
  return "${size.toStringAsFixed(size >= 10 ? 1 : 2)} ${units[unitIndex]}";
}

String _shortHash(String hash) => hash.length <= 12 ? hash : hash.substring(0, 12);
