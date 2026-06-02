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

final _remoteBundleImportOperationProvider =
    NotifierProvider<_RemoteBundleImportOperationNotifier, _RemoteBundleImportOperation?>(
      _RemoteBundleImportOperationNotifier.new,
    );

class _RemoteBundleImportOperationNotifier extends Notifier<_RemoteBundleImportOperation?> {
  @override
  _RemoteBundleImportOperation? build() => null;

  void clear() => state = null;

  void start(RemoteBundleArtifact artifact) {
    state = _RemoteBundleImportOperation.started(artifact);
  }

  void updateProgress(RemoteBundleArtifact artifact, RemoteBundleImportProgress progress) {
    final current = state;
    if (current?.artifact.artifactId != artifact.artifactId) {
      return;
    }
    state = current!.withProgress(progress);
  }

  void stop(RemoteBundleArtifact artifact) {
    final current = state;
    if (current?.artifact.artifactId == artifact.artifactId && current!.running) {
      state = current.stopped();
    }
  }

  void fail(RemoteBundleArtifact artifact, Object error) {
    final current = state;
    if (current?.artifact.artifactId == artifact.artifactId) {
      state = current!.withError(error);
    }
  }
}

class _RemoteBundleImportOperation {
  const _RemoteBundleImportOperation({
    required this.artifact,
    required this.progress,
    required this.running,
    this.error,
    this.failedStage,
  });

  factory _RemoteBundleImportOperation.started(RemoteBundleArtifact artifact) =>
      _RemoteBundleImportOperation(
        artifact: artifact,
        progress: RemoteBundleImportProgress(
          artifact: artifact,
          stage: RemoteBundleImportStage.preparing,
          bundleId: artifact.bundleId,
          baseBundleId: artifact.baseBundleId,
          baseManifestHash: artifact.baseManifestHash,
        ),
        running: true,
      );

  final RemoteBundleArtifact artifact;
  final RemoteBundleImportProgress progress;
  final bool running;
  final Object? error;
  final RemoteBundleImportStage? failedStage;

  String get bundleId => progress.bundleId ?? artifact.bundleId;
  bool get failed => error != null;
  bool get completed => progress.stage == RemoteBundleImportStage.completed;
  bool get cancelled => progress.stage == RemoteBundleImportStage.cancelled;

  _RemoteBundleImportOperation withProgress(RemoteBundleImportProgress progress) =>
      _RemoteBundleImportOperation(
        artifact: artifact,
        progress: progress,
        running: !progress.isTerminal,
      );

  _RemoteBundleImportOperation withError(Object error) => _RemoteBundleImportOperation(
    artifact: artifact,
    progress: progress,
    running: false,
    error: error,
    failedStage: progress.stage,
  );

  _RemoteBundleImportOperation stopped() => _RemoteBundleImportOperation(
    artifact: artifact,
    progress: progress,
    running: false,
    error: error,
    failedStage: failedStage,
  );
}

Future<void> _importRemoteBundle(
  BuildContext context,
  WidgetRef ref,
  RemoteBundleArtifact artifact, {
  bool confirmDownload = true,
}) async {
  final existingOperation = ref.read(_remoteBundleImportOperationProvider);
  if (existingOperation?.running ?? false) {
    return;
  }

  if (confirmDownload) {
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
  }

  final operationNotifier = ref.read(_remoteBundleImportOperationProvider.notifier)
    ..start(artifact);
  await ref
      .read(bundleManagerProvider.notifier)
      .addRemoteBundle(
        artifact,
        confirmIncrementalImpact: (report) => confirmBundleImpactWarning(context, ref, report),
        confirmReplacementImpact: (report) => confirmBundleImpactWarning(context, ref, report),
        confirmOverwrite: () async {
          if (!context.mounted) return false;
          return showConfirmDialog(context, title: context.l10n.bundleImportOverwriteTitle);
        },
        onProgress: (progress) => operationNotifier.updateProgress(artifact, progress),
      );
  ref.invalidate(remoteBundleCatalogManagerProvider);
  final current = ref.read(_remoteBundleImportOperationProvider);
  if (current?.artifact.artifactId != artifact.artifactId) {
    return;
  }
  ref
      .read(bundleManagerProvider)
      .when(
        data: (_) => operationNotifier.stop(artifact),
        error: (error, _) => operationNotifier.fail(artifact, error),
        loading: () {},
      );
}

Future<void> _selectInstalledBundleWithImpactWarning(
  BuildContext context,
  WidgetRef ref,
  String bundleId,
) async {
  final report = ref.read(bundleSwitchImpactProvider(bundleId));
  final confirmed = await confirmBundleImpactWarning(context, ref, report);
  if (!confirmed) {
    return;
  }
  await ref.read(bundleManagerProvider.notifier).selectBundle(bundleId);
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
          confirmReplacementImpact: (report) => confirmBundleImpactWarning(context, ref, report),
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
    final activeBundle = ref.watch(currentBundleProvider);
    final activeBundleId = activeBundle?.bundleId;
    final pendingBundleId = bundleState.isInitializing
        ? ref.read(bundleServiceProvider.notifier).pendingBundleId ?? bundleState.bundleId
        : null;
    final activeBundleInfo = activeBundleId == null ? null : bundleRegistry.bundles[activeBundleId];

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
          if (activeBundleInfo != null)
            _BundleTile(
              bundle: activeBundleInfo,
              activated: true,
              pending: pendingBundleId == activeBundleInfo.bundleId,
            ),
          for (final entry in bundleRegistry.bundles.entries.where(
            (entry) => entry.key != activeBundleInfo?.bundleId,
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
    final operation = ref.watch(_remoteBundleImportOperationProvider);
    final importRunning = operation?.running ?? false;
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
            if (operation != null) ...[
              const SizedBox(height: 12),
              _RemoteBundleImportOperationCard(
                operation: operation,
                showReviewAlternatives: true,
                margin: EdgeInsets.zero,
              ),
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
                    onPressed: importRunning
                        ? null
                        : () => _importRemoteBundle(context, ref, firstRecommended.artifact),
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
    RemoteBundleCandidateUnavailableReason.incompatibleBundleSchema =>
      context.l10n.bundleRemoteUnavailableIncompatibleSchema(
        version: artifact.bundleSchemaVersion,
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
    this.importDisabled = false,
    this.operation,
  });

  final RemoteBundleCandidate candidate;
  final String? currentAppVersion;
  final VoidCallback onImportPressed;
  final bool importDisabled;
  final _RemoteBundleImportOperation? operation;

  @override
  Widget build(BuildContext context) {
    final artifact = candidate.artifact;
    final activeOperation = operation;
    if (activeOperation != null) {
      return _RemoteBundleImportOperationCard(operation: activeOperation);
    }

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
      if (candidate.schemaVersionWarning != null)
        context.l10n.bundleRemoteSchemaVersionWarning(version: candidate.schemaVersionWarning!),
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
                onPressed: importDisabled ? null : onImportPressed,
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
              onPressed: importDisabled ? null : onImportPressed,
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

class _RemoteBundleImportOperationCard extends ConsumerWidget {
  const _RemoteBundleImportOperationCard({
    required this.operation,
    this.showReviewAlternatives = false,
    this.margin = const EdgeInsets.only(top: 8),
  });

  final _RemoteBundleImportOperation operation;
  final bool showReviewAlternatives;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final artifact = operation.artifact;
    final currentStage = operation.failed ? operation.failedStage : operation.progress.stage;
    final installed = ref
        .watch(bundleRegistryManagerProvider)
        .bundles
        .containsKey(operation.bundleId);
    final activeBundle = ref.watch(currentBundleProvider);
    final loadedBundle = activeBundle?.bundleId == operation.bundleId;
    final title = operation.failed
        ? context.l10n.bundleRemoteProgressFailedTitle
        : operation.completed && loadedBundle
        ? context.l10n.bundleManagerReadyTitle
        : _remoteImportStageLabel(context, operation.progress.stage);
    final description = _remoteImportOperationDescription(
      context,
      operation,
      loadedBundle: loadedBundle,
    );

    return Card(
      margin: margin,
      color: operation.failed ? theme.colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  operation.failed ? Icons.error_outline : Icons.downloading_outlined,
                  color: operation.failed ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(artifact.artifactId, style: theme.textTheme.bodyMedium),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(description, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (operation.progress.stage == RemoteBundleImportStage.downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: operation.progress.downloadFraction),
            ],
            const SizedBox(height: 12),
            _RemoteBundleImportTimeline(
              artifact: artifact,
              currentStage: currentStage,
              failed: operation.failed,
            ),
            if (operation.completed || operation.failed || operation.cancelled) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (operation.failed)
                    FilledButton.icon(
                      onPressed: () =>
                          _importRemoteBundle(context, ref, artifact, confirmDownload: false),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.bundleRemoteProgressRetryAction),
                    ),
                  if (showReviewAlternatives && operation.failed)
                    OutlinedButton.icon(
                      onPressed: () => context.router.push(const RemoteBundleSelectionRoute()),
                      icon: const Icon(Icons.manage_search_outlined),
                      label: Text(context.l10n.bundleRemoteReviewAction),
                    ),
                  if (operation.failed || operation.cancelled)
                    TextButton(
                      onPressed: () =>
                          ref.read(_remoteBundleImportOperationProvider.notifier).clear(),
                      child: Text(context.l10n.bundleRemoteProgressKeepCurrentAction),
                    ),
                  if (operation.completed && installed)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.router.push(BundleDetailRoute(bundleId: operation.bundleId)),
                      icon: const Icon(Icons.info_outline),
                      label: Text(context.l10n.bundleRemoteProgressViewInstalledAction),
                    ),
                  if (operation.completed && installed && !loadedBundle)
                    FilledButton.icon(
                      onPressed: () =>
                          _selectInstalledBundleWithImpactWarning(context, ref, operation.bundleId),
                      icon: const Icon(Icons.archive_outlined),
                      label: Text(context.l10n.bundleRemoteProgressLoadBundleAction),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemoteBundleImportTimeline extends StatelessWidget {
  const _RemoteBundleImportTimeline({
    required this.artifact,
    required this.currentStage,
    required this.failed,
  });

  final RemoteBundleArtifact artifact;
  final RemoteBundleImportStage? currentStage;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final stages = _remoteImportStagesFor(artifact, currentStage: currentStage);
    final currentIndex = currentStage == null ? -1 : stages.indexOf(currentStage!);
    return Column(
      children: [
        for (var index = 0; index < stages.length; index += 1)
          _RemoteBundleImportTimelineRow(
            stage: stages[index],
            first: index == 0,
            last: index == stages.length - 1,
            status: _timelineStatusFor(stages[index], index, currentIndex, failed),
          ),
      ],
    );
  }

  _RemoteBundleImportTimelineStatus _timelineStatusFor(
    RemoteBundleImportStage stage,
    int index,
    int currentIndex,
    bool failed,
  ) {
    if (currentIndex < 0) {
      return _RemoteBundleImportTimelineStatus.pending;
    }
    if (failed && index == currentIndex) {
      return _RemoteBundleImportTimelineStatus.failed;
    }
    if (index < currentIndex) {
      return _RemoteBundleImportTimelineStatus.completed;
    }
    if (index == currentIndex) {
      return switch (stage) {
        RemoteBundleImportStage.completed => _RemoteBundleImportTimelineStatus.completed,
        RemoteBundleImportStage.cancelled => _RemoteBundleImportTimelineStatus.cancelled,
        _ => _RemoteBundleImportTimelineStatus.current,
      };
    }
    return _RemoteBundleImportTimelineStatus.pending;
  }
}

class _RemoteBundleImportTimelineRow extends StatelessWidget {
  const _RemoteBundleImportTimelineRow({
    required this.stage,
    required this.first,
    required this.last,
    required this.status,
  });

  final RemoteBundleImportStage stage;
  final bool first;
  final bool last;
  final _RemoteBundleImportTimelineStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = switch (status) {
      _RemoteBundleImportTimelineStatus.completed => colorGreen,
      _RemoteBundleImportTimelineStatus.current => theme.colorScheme.primary,
      _RemoteBundleImportTimelineStatus.failed => theme.colorScheme.error,
      _RemoteBundleImportTimelineStatus.cancelled => theme.colorScheme.secondary,
      _RemoteBundleImportTimelineStatus.pending => theme.colorScheme.outline,
    };
    final icon = switch (status) {
      _RemoteBundleImportTimelineStatus.completed => Icons.check,
      _RemoteBundleImportTimelineStatus.current => Icons.more_horiz,
      _RemoteBundleImportTimelineStatus.failed => Icons.close,
      _RemoteBundleImportTimelineStatus.cancelled => Icons.block,
      _RemoteBundleImportTimelineStatus.pending => Icons.circle,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: _TimelineConnector(visible: !first, color: color),
                ),
                CircleAvatar(
                  radius: 10,
                  backgroundColor: color.withValues(alpha: 0.16),
                  child: Icon(
                    icon,
                    size: status == _RemoteBundleImportTimelineStatus.pending ? 8 : 14,
                  ),
                ),
                Expanded(
                  child: _TimelineConnector(visible: !last, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _remoteImportStageLabel(context, stage),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: status == _RemoteBundleImportTimelineStatus.current
                      ? FontWeight.w700
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({required this.visible, required this.color});

  final bool visible;
  final Color color;

  @override
  Widget build(BuildContext context) => visible
      ? ColoredBox(color: color.withValues(alpha: 0.35), child: const SizedBox(width: 2))
      : const SizedBox(width: 2);
}

enum _RemoteBundleImportTimelineStatus { completed, current, failed, cancelled, pending }

List<RemoteBundleImportStage> _remoteImportStagesFor(
  RemoteBundleArtifact artifact, {
  RemoteBundleImportStage? currentStage,
}) => [
  RemoteBundleImportStage.preparing,
  RemoteBundleImportStage.downloading,
  RemoteBundleImportStage.verifying,
  RemoteBundleImportStage.unpacking,
  RemoteBundleImportStage.importing,
  if (artifact.isIncremental) RemoteBundleImportStage.applyingIncrementalPatch,
  RemoteBundleImportStage.refreshingRegistry,
  if (currentStage == RemoteBundleImportStage.cancelled)
    RemoteBundleImportStage.cancelled
  else
    RemoteBundleImportStage.completed,
];

String _remoteImportStageLabel(BuildContext context, RemoteBundleImportStage stage) =>
    switch (stage) {
      RemoteBundleImportStage.preparing => context.l10n.bundleRemoteProgressPreparing,
      RemoteBundleImportStage.downloading => context.l10n.bundleRemoteProgressDownloading,
      RemoteBundleImportStage.verifying => context.l10n.bundleRemoteProgressVerifying,
      RemoteBundleImportStage.unpacking => context.l10n.bundleRemoteProgressUnpacking,
      RemoteBundleImportStage.importing => context.l10n.bundleRemoteProgressImporting,
      RemoteBundleImportStage.applyingIncrementalPatch =>
        context.l10n.bundleRemoteProgressApplyingIncrementalPatch,
      RemoteBundleImportStage.refreshingRegistry =>
        context.l10n.bundleRemoteProgressRefreshingRegistry,
      RemoteBundleImportStage.completed => context.l10n.bundleRemoteProgressCompleted,
      RemoteBundleImportStage.cancelled => context.l10n.bundleRemoteProgressCancelled,
    };

String? _remoteImportOperationDescription(
  BuildContext context,
  _RemoteBundleImportOperation operation, {
  required bool loadedBundle,
}) {
  if (operation.failed) {
    return context.l10n.bundleRemoteProgressFailedDescription(
      stage: _remoteImportStageLabel(context, operation.failedStage ?? operation.progress.stage),
      message: operation.error.toString(),
    );
  }
  if (operation.cancelled) {
    return context.l10n.bundleRemoteProgressCancelledDescription;
  }
  if (operation.completed) {
    if (loadedBundle) {
      return context.l10n.bundleManagerReadyDescription(bundleId: operation.bundleId);
    }
    return context.l10n.bundleRemoteProgressCompletedDescription(bundleId: operation.bundleId);
  }
  final progress = operation.progress;
  if (progress.stage == RemoteBundleImportStage.downloading && progress.receivedBytes != null) {
    final received = _formatByteSize(progress.receivedBytes!);
    final total = progress.totalBytes;
    final fraction = progress.downloadFraction;
    if (total != null && fraction != null) {
      return context.l10n.bundleRemoteProgressDownloadingKnown(
        received: received,
        total: _formatByteSize(total),
        percent: (fraction * 100).clamp(0, 100).toStringAsFixed(0),
      );
    }
    return context.l10n.bundleRemoteProgressDownloadingUnknown(received: received);
  }
  if (progress.stage == RemoteBundleImportStage.applyingIncrementalPatch &&
      progress.baseBundleId != null) {
    return context.l10n.bundleRemoteArtifactBaseBundle(bundleId: progress.baseBundleId!);
  }
  return context.l10n.bundleRemoteProgressQueued;
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
