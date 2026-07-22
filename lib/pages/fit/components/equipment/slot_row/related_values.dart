part of "../../../page.dart";

typedef _SlotRelatedValueSegment = ({int iconAttributeId, String text});

native.Item? _resolveNativeModuleItem(FitContext fitContext, _ItemSlotInfo slotInfo) {
  for (final item in fitContext.emulated?.modules ?? const <native.Item>[]) {
    if (item.slot.slotType == slotInfo.type && item.slot.index == slotInfo.index) {
      return item;
    }
  }
  return null;
}

String _formatRangeKm(double meters) => "${(meters / 1000).toStringAsMaxDecimals(1)} km";

List<_SlotRelatedValueSegment> _collectSlotRelatedValues(native.Item item) {
  final segments = <_SlotRelatedValueSegment>[];

  final optimalRange = item.getAttribute(EveConstAttrID.maxRange);
  if (optimalRange > 0) {
    var text = _formatRangeKm(optimalRange);
    final falloffRange = item.getAttribute(EveConstAttrID.falloff);
    if (falloffRange > 0) {
      text += " + ${_formatRangeKm(falloffRange)}";
    }
    final falloffEffectivenessRange = item.getAttribute(EveConstAttrID.falloffEffectiveness);
    if (falloffEffectivenessRange > 0) {
      text += " + ${_formatRangeKm(falloffEffectivenessRange)}";
    }
    segments.add((iconAttributeId: EveConstAttrID.maxRange, text: text));
  } else {
    final charge = item.charge;
    final missileRangeMeters = charge == null
        ? 0.0
        : charge.getAttribute(EveConstAttrID.maxVelocity) *
              charge.getAttribute(EveConstAttrID.explosionDelay) /
              1000;
    if (missileRangeMeters > 0) {
      segments.add((
        iconAttributeId: EveConstAttrID.maxRange,
        text: _formatRangeKm(missileRangeMeters),
      ));
    } else {
      final fieldRange = item.getAttribute(EveConstAttrID.empFieldRange);
      if (fieldRange > 0) {
        segments.add((iconAttributeId: EveConstAttrID.maxRange, text: _formatRangeKm(fieldRange)));
      }
    }
  }

  final cycleTimeMs = item.getAttribute(EveConstExtendedAttrID.cycleTime);
  if (cycleTimeMs > 0) {
    final capacitorPerSecond = item.getAttribute(EveConstAttrID.capacitorNeed) / cycleTimeMs * 1000;
    if (capacitorPerSecond > 0.001) {
      segments.add((
        iconAttributeId: EveConstAttrID.capacitorNeed,
        text: "${capacitorPerSecond.toStringAsMaxDecimals(1)} GJ/s",
      ));
    }
  }

  return segments;
}

class _SlotRelatedValuesRow extends ConsumerWidget {
  const _SlotRelatedValuesRow({required this.segments});

  final List<_SlotRelatedValueSegment> segments;

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
