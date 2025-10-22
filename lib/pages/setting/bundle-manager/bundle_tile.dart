part of "page.dart";

class _BundleTile extends ConsumerWidget {
  const _BundleTile({required this.bundle, this.activated = false});
  final BundleInfo bundle;
  final bool activated;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          ClickableCircleAvatar(
            onTap: (!activated).then(
              () =>
                  () => unawaited(
                    ref.read(bundleManagerProvider.notifier).selectBundle(bundle.bundleId),
                  ),
            ),
            backgroundColor: activated.thenSome(colorGreen),
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
                      color: activated.thenSome(colorGreen),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    bundle.region,
                    style: context.theme.textTheme.labelSmall?.copyWith(
                      color: context.theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
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
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.delete, color: context.theme.colorScheme.error),
            tooltip: context.l10n.delete,
            onPressed: () async {
              final remove = await showConfirmDialog(
                context,
                title: context.l10n.bundleManagerDeleteBundleConfirmTitle,
                content: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: context.l10n.bundleManagerDeleteBundleConfirmContent(
                          bundleId: bundle.bundleId,
                        ),
                      ),
                      if (bundle.bundleId ==
                          ref.read(bundleRegistryManagerProvider).selectedBundleId) ...[
                        const TextSpan(text: "\n\n"),
                        TextSpan(
                          text: context.l10n.bundleManagerDeleteBundleInUseWarning,
                          style: TextStyle(color: context.theme.colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              );
              if (remove) {
                unawaited(ref.read(bundleManagerProvider.notifier).removeBundle(bundle.bundleId));
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: context.theme.colorScheme.primary),
            tooltip: context.l10n.showInfo,
            onPressed: () => context.router.push(BundleDetailRoute(bundleId: bundle.bundleId)),
          ),
        ],
      ),
    ),
  );
}
