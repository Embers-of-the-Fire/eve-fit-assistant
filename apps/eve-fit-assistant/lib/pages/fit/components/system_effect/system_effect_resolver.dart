import "package:eve_fit_assistant/pages/fit/components/system_effect/system_effect_catalog.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";

/// Raw dogma attributes of a type in the active snapshot, or null when the
/// type is absent from it. Sourced from the fit engine at runtime.
typedef DogmaAttributesOf = Map<int, double>? Function(int typeId);

/// The `warfareBuff1-4ID/Value` dogma attribute pairs through which the
/// client delivers abyssal weather and hazard cloud effects.
const warfareBuffAttributePairs = [(2468, 2469), (2470, 2471), (2472, 2473), (2536, 2537)];

/// Expands a preset into concrete [FitSystemBuff] entries using the active
/// snapshot's beacon dogma.
///
/// Returns null when the preset cannot be resolved in the active snapshot
/// (beacon type absent, or beacon dogma yields no buffs) — callers must
/// treat such presets as unavailable, never as an error.
List<FitSystemBuff>? resolvePresetBuffs(SystemEffectPreset preset, DogmaAttributesOf attrsOf) {
  final staticBuffs = preset.staticBuffs;
  if (staticBuffs != null) return staticBuffs;

  final beaconTypeId = preset.beaconTypeId;
  if (beaconTypeId == null) return null;
  final attrs = attrsOf(beaconTypeId);
  if (attrs == null) return null;

  final buffs = preset.warfareFromBeacon
      ? _resolveWarfareBuffs(preset.id, attrs)
      : _resolveMappedBuffs(preset.id, preset.buffAttrs ?? const {}, attrs);
  return buffs.isEmpty ? null : buffs;
}

List<FitSystemBuff> _resolveWarfareBuffs(String presetId, Map<int, double> attrs) => [
  for (final (idAttribute, valueAttribute) in warfareBuffAttributePairs)
    if (attrs[idAttribute] case final buffId? when buffId != 0)
      if (attrs[valueAttribute] case final value?)
        FitSystemBuff(buffId: buffId.round(), value: value, presetId: presetId),
];

List<FitSystemBuff> _resolveMappedBuffs(
  String presetId,
  Map<int, int> buffAttrs,
  Map<int, double> attrs,
) => [
  for (final MapEntry(key: buffId, value: attributeId) in buffAttrs.entries)
    if (attrs[attributeId] case final value?)
      FitSystemBuff(buffId: buffId, value: value, presetId: presetId),
];

/// Resolves the pre-filled strength of a custom-buff library entry from the
/// active snapshot (weakest tier/class of the effect), falling back to
/// [SystemBuffLibraryEntry.staticDefault] and then to 1.0 when the beacon
/// does not resolve.
double resolveLibraryDefaultValue(SystemBuffLibraryEntry entry, DogmaAttributesOf attrsOf) {
  final beaconTypeId = entry.defaultBeaconTypeId;
  if (beaconTypeId != null) {
    final attrs = attrsOf(beaconTypeId);
    if (attrs != null) {
      final attributeId = entry.defaultAttrId;
      if (attributeId != null) {
        final value = attrs[attributeId];
        if (value != null) return value;
      } else {
        for (final (idAttribute, valueAttribute) in warfareBuffAttributePairs) {
          if (attrs[idAttribute]?.round() == entry.buffId) {
            final value = attrs[valueAttribute];
            if (value != null) return value;
          }
        }
      }
    }
  }
  return entry.staticDefault ?? 1.0;
}
