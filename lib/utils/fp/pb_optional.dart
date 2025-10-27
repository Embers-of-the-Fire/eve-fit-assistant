part of "../fp.dart";

extension PbOptionalInt on int {
  int? get pbOptional => this == 0 ? null : this;
}

extension PbOptionalFloat on double {
  double? get pbOptional => this == 0.0 ? null : this;
}
