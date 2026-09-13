part of "../../native.dart";

/// Capacitor warfare (energy neutralization / nosferatu) defense statistics.
///
/// The estimates answer "what must an attacker invest" and are meant to be
/// compared against neutralizer output; capacitor regeneration is not counted.

/// Fraction (0..1) of incoming neutralizer/nosferatu drain the ship resists.
///
/// [energyWarfareResistance] is the dogma attribute multiplier
/// ([EveConstAttrID.energyWarfareResistance], default 1.0 = no resistance).
double neutralizationResistanceRate(double energyWarfareResistance) =>
    (1 - energyWarfareResistance).clamp(0.0, 1.0);

/// Sustained incoming drain rate (GJ/s, pre-resistance) needed to break the
/// peak recharge margin of a self-sustainable (capacitor-stable) fit.
///
/// [peakDelta] is `capacitorPeakRecharge - capacitorPeakLoad` in GJ/s.
/// Returns [double.infinity] when the ship resists all incoming drain.
double neutralizationBreakPeakRate({
  required double peakDelta,
  required double energyWarfareResistance,
}) => energyWarfareResistance > 0 ? max(peakDelta, 0) / energyWarfareResistance : double.infinity;

/// Total GJ of neutralization (pre-resistance) needed to empty a full
/// capacitor of a fit that is not self-sustainable.
///
/// Regeneration during the drain is deliberately not counted: the value is
/// meant to be compared directly against neutralizer output.
/// Returns [double.infinity] when the ship resists all incoming drain.
double neutralizationClearAmount({
  required double capacity,
  required double energyWarfareResistance,
}) => energyWarfareResistance > 0 ? capacity / energyWarfareResistance : double.infinity;
