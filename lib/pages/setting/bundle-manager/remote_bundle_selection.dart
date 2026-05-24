part of "page.dart";

@RoutePage()
class RemoteBundleSelectionPage extends ConsumerWidget {
  const RemoteBundleSelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(remoteBundleCatalogManagerProvider);
    return Layout(
      title: context.l10n.bundleRemoteSelectionPageTitle,
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _RemoteBundleSelectionMessage(
          icon: Icons.error_outline,
          message: context.l10n.bundleRemoteError(message: error.toString()),
          action: TextButton.icon(
            onPressed: () => ref.invalidate(remoteBundleCatalogManagerProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.bundleRemoteRefreshAction),
          ),
        ),
        data: (catalogState) => _RemoteBundleSelectionContent(state: catalogState),
      ),
    );
  }
}

class _RemoteBundleSelectionContent extends ConsumerWidget {
  const _RemoteBundleSelectionContent({required this.state});

  final RemoteBundleCatalogState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.enabled) {
      return _RemoteBundleSelectionMessage(
        icon: Icons.cloud_off_outlined,
        message: context.l10n.bundleRemoteDisabled,
      );
    }
    if (state.error != null) {
      return _RemoteBundleSelectionMessage(
        icon: Icons.error_outline,
        message: context.l10n.bundleRemoteError(message: state.error!),
        action: TextButton.icon(
          onPressed: () => ref.invalidate(remoteBundleCatalogManagerProvider),
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.bundleRemoteRefreshAction),
        ),
      );
    }
    if (!state.catalogAvailable) {
      return _RemoteBundleSelectionMessage(
        icon: Icons.folder_off_outlined,
        message: context.l10n.bundleRemoteCatalogMissing,
      );
    }
    if (state.candidates.isEmpty) {
      return _RemoteBundleSelectionMessage(
        icon: Icons.inventory_2_outlined,
        message: context.l10n.bundleRemoteCatalogEmpty,
      );
    }

    final content = [
      _RemoteBundleSelectionHeader(state: state),
      _RemoteBundleCandidateGroup(
        title: context.l10n.bundleRemoteRecommendedSection,
        description: context.l10n.bundleRemoteRecommendedSectionDescription,
        candidates: state.recommended,
        currentAppVersion: state.appVersion,
      ),
      _RemoteBundleCandidateGroup(
        title: context.l10n.bundleRemoteAvailableSection,
        description: context.l10n.bundleRemoteAvailableSectionDescription,
        candidates: state.available,
        currentAppVersion: state.appVersion,
      ),
      _RemoteBundleCandidateGroup(
        title: context.l10n.bundleRemoteInstalledSection,
        description: context.l10n.bundleRemoteInstalledSectionDescription,
        candidates: state.installed,
        currentAppVersion: state.appVersion,
      ),
      _RemoteBundleCandidateGroup(
        title: context.l10n.bundleRemoteUnavailableSection,
        description: context.l10n.bundleRemoteUnavailableSectionDescription,
        candidates: state.unavailable,
        currentAppVersion: state.appVersion,
      ),
      const SizedBox(height: 20),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (!wide) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: content,
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView(padding: const EdgeInsets.symmetric(vertical: 10), children: content),
      ),
    );
  }
}

class _RemoteBundleSelectionHeader extends StatelessWidget {
  const _RemoteBundleSelectionHeader({required this.state});

  final RemoteBundleCatalogState state;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_outlined, color: context.theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.bundleRemoteSelectionSummaryTitle,
                  style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.bundleRemoteSelectionSummaryDescription,
            style: context.theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _RemoteBundleCounts(state: state),
        ],
      ),
    ),
  );
}

class _RemoteBundleCandidateGroup extends ConsumerWidget {
  const _RemoteBundleCandidateGroup({
    required this.title,
    required this.description,
    required this.candidates,
    required this.currentAppVersion,
  });

  final String title;
  final String description;
  final Iterable<RemoteBundleCandidate> candidates;
  final String? currentAppVersion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidateList = candidates.toList(growable: false);
    if (candidateList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(description, style: context.theme.textTheme.bodySmall),
          ),
          const SizedBox(height: 4),
          for (final candidate in candidateList)
            _RemoteBundleArtifactTile(
              candidate: candidate,
              currentAppVersion: currentAppVersion,
              onImportPressed: () => _importRemoteBundle(context, ref, candidate.artifact),
            ),
        ],
      ),
    );
  }
}

class _RemoteBundleSelectionMessage extends StatelessWidget {
  const _RemoteBundleSelectionMessage({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: context.theme.colorScheme.secondary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
