import "dart:math" as math;

import "package:efa_constant/eve.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/native.dart";

/// Spool-up state of a precursor turret (Entropic Disintegrator).
///
/// The turret gains `damageMultiplierBonusPerCycle` damage per completed
/// damage turn, up to `damageMultiplierBonusMax`. [turns] is the number of
/// completed turns (0 = first shot, base damage), so the turret is firing its
/// `turns + 1`-th round.
class PrecursorTurretSpool {
  const PrecursorTurretSpool({
    required this.turns,
    required this.maxTurns,
    required this.minDps,
    required this.maxDps,
    required this.currentDps,
  });

  final int turns;
  final int maxTurns;

  /// DPS of the first shot, without any ramp-up bonus.
  final double minDps;

  /// DPS once the maximum ramp-up bonus is reached.
  final double maxDps;

  /// DPS at [turns], as calculated by the fitting engine.
  final double currentDps;
}

/// Compute the spool state of a module, or null if it is not a precursor
/// turret dealing damage. Mirrors the engine's `pass_6::precursor_turret`.
PrecursorTurretSpool? precursorTurretSpool(native.Item item, FitModuleItem slot) {
  final perCycle = item.getAttribute(EveConstAttrID.damageMultiplierBonusPerCycle);
  final maxBonus = item.getAttribute(EveConstAttrID.damageMultiplierBonusMax);
  if (perCycle <= 0 || maxBonus <= 0) return null;

  final dps = item.getAttribute(EveConstExtendedAttrID.damagePerSecondWithoutReload);
  if (dps <= 0) return null;

  final isActive = switch (slot.state) {
    FitItemState.active || FitItemState.overload => true,
    _ => false,
  };

  final maxTurns = (maxBonus / perCycle).ceil();
  final turns = slot.damageTurns.clamp(0, maxTurns);

  // The engine only ramps up a firing (active) turret.
  final factor = isActive ? 1 + math.min(turns * perCycle, maxBonus) : 1.0;
  final minDps = dps / factor;

  return PrecursorTurretSpool(
    turns: turns,
    maxTurns: maxTurns,
    minDps: minDps,
    maxDps: minDps * (1 + maxBonus),
    currentDps: dps,
  );
}
