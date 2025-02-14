import 'dart:math';

/// Returns: a percentage value of the stable point. 0 <= value <= 100
///          -1 if invalid input.
double capacitorStableAt({
  required double capacity,
  required double targetRechargeRage,
  required double rechargeTime,
}) {
  /*
  Algorithm: source: https://wiki.eveuniversity.org/Capacitor

  Equation solution:
    (5*Cm + sqrt(-10*Cm*T*v + 25*Cm^2) - v*T)/(10*Cm)
    or
    (5*Cm - sqrt(-10*Cm*T*v + 25*Cm^2) - v*T)/(10*Cm)
   */
  final v = targetRechargeRage;
  final T = rechargeTime / 1000;
  // ignore: non_constant_identifier_names
  final Cm = capacity;

  final delta = -10 * Cm * T * v + 25 * Cm * Cm;
  if (delta < 0) {
    return -1;
  }
  final sqrtDelta = sqrt(delta);
  final solve1 = (5 * Cm + sqrtDelta - v * T) / (10 * Cm);
  final solve2 = (5 * Cm - sqrtDelta - v * T) / (10 * Cm);
  return max(solve1, solve2) * 100;
}
