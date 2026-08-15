part of "../../../page.dart";

native.Item? _resolveNativeModuleItem(FitContext fitContext, _ItemSlotInfo slotInfo) {
  for (final item in fitContext.emulated?.modules ?? const <native.Item>[]) {
    if (item.slot.slotType == slotInfo.type && item.slot.index == slotInfo.index) {
      return item;
    }
  }
  return null;
}

class _SlotRelatedValuesRow extends ConsumerWidget {
  const _SlotRelatedValuesRow({required this.segments});

  final List<SlotRelatedValueSegment> segments;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 10,
    runSpacing: 4,
    children: [
      for (final segment in segments)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EveIcon(
              icon:
                  ref.watch(
                    repoCollectionProvider.select(
                      (c) => c?.getDogmaAttribute(segment.iconAttributeId)?.icon,
                    ),
                  ) ??
                  pb_utils.Icon(),
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(segment.text, style: const TextStyle(fontSize: 14)),
          ],
        ),
    ],
  );
}
