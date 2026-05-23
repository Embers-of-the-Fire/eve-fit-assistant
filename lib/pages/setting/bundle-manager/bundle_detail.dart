part of "page.dart";

@RoutePage()
class BundleDetailPage extends ConsumerStatefulWidget {
  const BundleDetailPage({required this.bundleId, super.key});

  final String bundleId;

  @override
  ConsumerState<BundleDetailPage> createState() => _BundleDetailPageState();
}

class _BundleDetailPageState extends ConsumerState<BundleDetailPage> {
  AsyncValue<BundleVerificationReport?> verificationState =
      const AsyncValue<BundleVerificationReport?>.data(null);

  Future<void> _verifyBundle(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.bundleVerificationConfirmTitle,
      content: Text(context.l10n.bundleVerificationConfirmMessage),
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    setState(() {
      verificationState = const AsyncValue<BundleVerificationReport?>.loading();
    });
    final result = await AsyncValue.guard(
      () => const BundleVerificationService().verifyInstalledBundle(widget.bundleId),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      verificationState = result;
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleRegistry = ref.watch(bundleRegistryManagerProvider);
    final activeBundleId = ref.watch(currentBundleProvider)?.bundleId;
    final bundle = bundleRegistry.bundles[widget.bundleId];
    if (bundle == null) {
      return Layout(
        title: context.l10n.bundleManagerDetailPageTitle,
        child: Center(child: Text(context.l10n.bundleManagerDetailUnavailableMessage)),
      );
    }

    final bundleIsSelected = activeBundleId == widget.bundleId;
    BundleRegistrar? bundleRegistrar;
    Object? registrarError;
    try {
      bundleRegistrar = BundleRegistryManager.getRegistrar(widget.bundleId);
    } on Object catch (error) {
      registrarError = error;
    }
    final registrar = bundleRegistrar;

    String formatTs(int ts) =>
        yMMMMdHmsLocalized(context).format(DateTime.fromMillisecondsSinceEpoch(ts).toLocal());

    return Layout(
      title: bundle.bundleId,
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            Row(
              children: [
                CircleAvatar(
                  backgroundColor: bundleIsSelected.thenSome(colorGreen),
                  child: Icon(Icons.archive, color: context.theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              bundle.bundleId,
                              style: context.theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: bundleIsSelected.thenSome(colorGreen),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const .symmetric(horizontal: 8, vertical: 2),
                            child: Text(
                              bundle.region,
                              style: context.theme.textTheme.labelSmall?.copyWith(
                                color: context.theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 16,
                        runSpacing: 2,
                        children: [
                          _BundleMetadataText(
                            label: context.l10n.bundleManagerBundleAppVersion,
                            value: bundle.version,
                          ),
                          _BundleMetadataText(
                            label: context.l10n.bundleManagerBundleBuild,
                            value: bundle.build,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            if (registrar == null) ...[
              const SizedBox(height: 12),
              Text(context.l10n.bundleManagerDetailUnavailableMessage),
              if (registrarError != null) ...[
                const SizedBox(height: 8),
                Text(registrarError.toString(), style: context.theme.textTheme.bodySmall),
              ],
            ] else ...[
              Text(
                context.l10n.bundleManagerDetailSectionTitleLatestPatch,
                style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              _PatchTile(patch: registrar.latest, formatTs: formatTs),
              const SizedBox(height: 12),
              _BundleVerificationCard(
                state: verificationState,
                onVerifyPressed: () => _verifyBundle(context),
                formatTs: (time) => yMMMMdHmsLocalized(context).format(time.toLocal()),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.bundleManagerDetailSectionTitleHistory,
                style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    final patch = registrar.history[registrar.history.length - 1 - index];
                    return _PatchTile(patch: patch, formatTs: formatTs);
                  },
                  separatorBuilder: (_, _) => const Divider(),
                  itemCount: registrar.history.length,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BundleVerificationCard extends StatelessWidget {
  const _BundleVerificationCard({
    required this.state,
    required this.onVerifyPressed,
    required this.formatTs,
  });

  final AsyncValue<BundleVerificationReport?> state;
  final VoidCallback onVerifyPressed;
  final String Function(DateTime) formatTs;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final report = state.valueOrNull;
    final status = report?.status;
    final color = switch (status) {
      BundleVerificationStatus.valid => colorGreen,
      BundleVerificationStatus.warning => theme.colorScheme.tertiary,
      BundleVerificationStatus.invalid => theme.colorScheme.error,
      null => theme.colorScheme.secondary,
    };
    final icon = switch (status) {
      BundleVerificationStatus.valid => Icons.verified_outlined,
      BundleVerificationStatus.warning => Icons.warning_amber_outlined,
      BundleVerificationStatus.invalid => Icons.error_outline,
      null => Icons.fact_check_outlined,
    };
    final title = switch (status) {
      BundleVerificationStatus.valid => context.l10n.bundleVerificationValid,
      BundleVerificationStatus.warning => context.l10n.bundleVerificationWarning,
      BundleVerificationStatus.invalid => context.l10n.bundleVerificationInvalid,
      null => context.l10n.bundleVerificationNeverRun,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.bundleVerificationTitle,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: state.isLoading ? null : onVerifyPressed,
                  icon: state.isLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(context.l10n.bundleVerificationAction),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
            if (report != null) ...[
              const SizedBox(height: 4),
              Text(
                context.l10n.bundleVerificationCheckedAt(formatTs(report.checkedAt)),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _BundleVerificationSummary(report: report),
              if (report.issues.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final issue in report.issues.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _formatVerificationIssue(context, issue),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (report.issues.length > 8)
                  Text(
                    context.l10n.bundleVerificationMoreIssues(report.issues.length - 8),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ],
            state.whenOrNull(
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error.toString(), style: theme.textTheme.bodySmall),
                  ),
                ) ??
                const SizedBox.shrink(),
            const SizedBox(height: 6),
            Text(
              context.l10n.bundleVerificationRemoteRepairUnavailable,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _BundleVerificationSummary extends StatelessWidget {
  const _BundleVerificationSummary({required this.report});

  final BundleVerificationReport report;

  @override
  Widget build(BuildContext context) {
    final summaries = <String>[
      context.l10n.bundleVerificationMissingFiles(
        report.countIssues<BundleVerificationMissingFile>(),
      ),
      context.l10n.bundleVerificationHashMismatches(
        report.countIssues<BundleVerificationHashMismatch>(),
      ),
      context.l10n.bundleVerificationSizeMismatches(
        report.countIssues<BundleVerificationSizeMismatch>(),
      ),
      context.l10n.bundleVerificationExtraFiles(report.countIssues<BundleVerificationExtraFile>()),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        for (final summary in summaries) Text(summary, style: context.theme.textTheme.bodySmall),
      ],
    );
  }
}

String _formatVerificationIssue(BuildContext context, BundleVerificationIssue issue) =>
    switch (issue) {
      BundleVerificationMissingManifest(:final path) =>
        context.l10n.bundleVerificationIssueMissingManifest(path),
      BundleVerificationInvalidManifest(:final path, :final error) =>
        context.l10n.bundleVerificationIssueInvalidManifest(path, error),
      BundleVerificationManifestHashMissing() =>
        context.l10n.bundleVerificationIssueManifestHashMissing,
      BundleVerificationManifestHashMismatch(:final expected, :final actual) =>
        context.l10n.bundleVerificationIssueManifestHashMismatch(expected, actual),
      BundleVerificationUnsafeManifestPath(:final path) =>
        context.l10n.bundleVerificationIssueUnsafeManifestPath(path),
      BundleVerificationMissingFile(:final path) => context.l10n.bundleVerificationIssueMissingFile(
        path,
      ),
      BundleVerificationSizeMismatch(:final path, :final expected, :final actual) =>
        context.l10n.bundleVerificationIssueSizeMismatch(path, expected, actual),
      BundleVerificationHashMismatch(:final path, :final expected, :final actual) =>
        context.l10n.bundleVerificationIssueHashMismatch(path, expected, actual),
      BundleVerificationExtraFile(:final path) => context.l10n.bundleVerificationIssueExtraFile(
        path,
      ),
      BundleVerificationReadError(:final path, :final error) =>
        context.l10n.bundleVerificationIssueReadError(path, error),
    };

class _PatchTile extends StatelessWidget {
  const _PatchTile({required this.patch, required this.formatTs});

  final BundleHistoryPatch patch;
  final String Function(int) formatTs;

  @override
  Widget build(BuildContext context) {
    final loc = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "${loc.bundleManagerBundleAppVersion}${patch.appVersion}",
              style: context.theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: 24),
            Text(
              patch.isIncremental
                  ? loc.bundleManagerDetailVariantIncremental
                  : loc.bundleManagerDetailVariantFull,
              style: context.theme.textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "${loc.bundleManagerBundleBuild}${patch.gameBuild}",
          style: context.theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 2),
        Text(
          "${loc.bundleManagerBundleGameVersion}${patch.gameVersion}",
          style: context.theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 2),
        Text(
          "${loc.bundleManagerBundleServer}${patch.gameServer}",
          style: context.theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 2),
        Text(
          "${loc.bundleManagerBundleRegion}${patch.gameRegion}",
          style: context.theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          "${loc.bundleManagerBundleBranch}${patch.gameBranch}",
          style: context.theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          "${loc.bundleManagerDetailGeneratedAt}${formatTs(patch.generateTimestamp * 1000)}",
          style: context.theme.textTheme.bodySmall,
        ),
        Text(
          "${loc.bundleManagerDetailLoadedAt}${formatTs(patch.loadTimestamp)}",
          style: context.theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
