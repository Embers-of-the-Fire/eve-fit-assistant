extension EnsureFiniteExt on double {
  /// Ensures that the double is finite; if not, returns a the `maxFinite` value.
  double get ensureFinite => isFinite
      ? this
      : isNegative
      ? -double.maxFinite
      : double.maxFinite;
}
