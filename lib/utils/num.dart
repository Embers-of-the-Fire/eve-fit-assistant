extension ZeroOptionalInt on int {
  int? get optional => this == 0 ? null : this;
}

extension ZeroOptionalDouble on double {
  double? get optional => this == 0 ? null : this;
}
