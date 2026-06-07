part of "page.dart";

class _BundleTile extends ConsumerWidget {
  const _BundleTile({required this.bundle, this.activated = false, this.pending = false});
  final BundleInfo bundle;
  final bool activated;
  final bool pending;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const .symmetric(horizontal: 12, vertical: 6),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const .symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          ClickableCircleAvatar(
            onTap: (!(activated || pending)).then(
              () =>
                  () => unawaited(_selectBundleWithImpactWarning(context, ref, bundle.bundleId)),
            ),
            backgroundColor: activated.thenSome(colorGreen),
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
                        bundle.displayName(context),
                        style: context.theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: activated.thenSome(colorGreen),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pending) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                    if (bundle.versionBadge case final v?)
                      Container(
                        padding: const .symmetric(horizontal: 8, vertical: 2),
                        child: Text(
                          v,
                          style: context.theme.textTheme.labelSmall?.copyWith(
                            color: context.theme.colorScheme.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const .symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "v${bundle.bundleSchemaVersion}",
                        style: context.theme.textTheme.labelSmall?.copyWith(
                          color: context.theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bundle.buildLabel(context),
                  style: context.theme.textTheme.bodyMedium,
                ),
                if (bundle.generatedLabel(
                  (ts) =>
                      yMMMMdHmsLocalized(context)
                          .format(DateTime.fromMillisecondsSinceEpoch(ts).toLocal()),
                )
                    case final label?)
                  Text(label, style: context.theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(Icons.delete, color: context.theme.colorScheme.error),
            tooltip: context.l10n.delete,
            onPressed: pending
                ? null
                : () async {
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
                            if (activated || pending) ...[
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
                      unawaited(
                        ref.read(bundleManagerProvider.notifier).removeBundle(bundle.bundleId),
                      );
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

  Future<void> _selectBundleWithImpactWarning(
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
}
