part of "page.dart";

@RoutePage()
class BundleDetailPage extends ConsumerWidget {
  const BundleDetailPage({required this.bundleId, super.key});

  final String bundleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleRegistry = ref.watch(bundleRegistryManagerProvider);
    final bundle = bundleRegistry.bundles[bundleId]!;
    final bundleIsSelected = bundleRegistry.selectedBundleId == bundleId;
    final bundleRegistrar = BundleRegistryManager.getRegistrar(bundleId);

    String formatTs(int ts) =>
        yMMMMdHmsLocalized(context).format(DateTime.fromMillisecondsSinceEpoch(ts).toLocal());

    return Layout(
      title: bundle.bundleId,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          bundle.bundleId,
                          style: context.theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: bundleIsSelected.thenSome(colorGreen),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Text(
                          bundle.region,
                          style: context.theme.textTheme.labelSmall?.copyWith(
                            color: context.theme.colorScheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                context.l10n.bundleManagerBundleAppVersion,
                                style: context.theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(bundle.version, style: context.theme.textTheme.bodyMedium),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                context.l10n.bundleManagerBundleBuild,
                                style: context.theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(bundle.build, style: context.theme.textTheme.bodyMedium),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              context.l10n.bundleManagerDetailSectionTitleLatestPatch,
              style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            _PatchTile(patch: bundleRegistrar.latest, formatTs: formatTs),
            const SizedBox(height: 12),
            Text(
              context.l10n.bundleManagerDetailSectionTitleHistory,
              style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // History list (visual style references parent page list appearance)
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final patch = bundleRegistrar.history[bundleRegistrar.history.length - 1 - index];
                  return _PatchTile(patch: patch, formatTs: formatTs);
                },
                separatorBuilder: (_, __) => const Divider(),
                itemCount: bundleRegistrar.history.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
