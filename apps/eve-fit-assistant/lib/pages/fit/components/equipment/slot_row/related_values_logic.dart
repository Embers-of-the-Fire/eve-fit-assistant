import "package:efa_constant/eve.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/utils/native.dart";
import "package:eve_fit_assistant/utils/num.dart";

typedef SlotRelatedValueSegment = ({int iconAttributeId, String text});

String _formatRangeKm(double meters) => "${(meters / 1000).toStringAsMaxDecimals(1)} km";

List<SlotRelatedValueSegment> collectSlotRelatedValues(native.Item item) {
  final segments = <SlotRelatedValueSegment>[];

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
