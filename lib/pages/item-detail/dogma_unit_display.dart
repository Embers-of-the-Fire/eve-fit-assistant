import "dart:math" as math;

import "package:eve_fit_assistant/data/proto/dogma_units.pb.dart";
import "package:eve_fit_assistant/storage/bundle/service/localization.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart" as intl;

const double _metersPerAu = 149597870700;

enum DogmaUnitSignMode { none, positive }

typedef DogmaUnitIdResolver = String? Function(int id);

String formatDogmaUnitValue(
  BuildContext context,
  WidgetRef ref,
  DogmaUnit? unit,
  double value, {
  DogmaUnitSignMode signMode = DogmaUnitSignMode.none,
  DogmaUnitIdResolver? resolveGroupId,
  DogmaUnitIdResolver? resolveTypeId,
  DogmaUnitIdResolver? resolveAttributeId,
}) {
  if (unit == null) {
    return _formatAdaptiveNumber(context, value, maxDecimalDigits: 3, signMode: signMode);
  }

  return switch (unit.dogmaUnitId) {
    1 => _formatDistance(context, value, signMode: signMode),
    2 => _formatWithUnit(context, value, "kg", decimalDigits: 0, signMode: signMode),
    3 || 123 => _formatSeconds(context, value, signMode: signMode),
    4 => _formatWithUnit(context, value, "A", decimalDigits: 2, signMode: signMode),
    5 => _formatWithUnit(context, value, "K", decimalDigits: 2, signMode: signMode),
    6 => _formatWithUnit(context, value, "mol", decimalDigits: 2, signMode: signMode),
    7 => _formatWithUnit(context, value, "cd", decimalDigits: 2, signMode: signMode),
    8 => _formatWithUnit(context, value, "m2", decimalDigits: 2, signMode: signMode),
    9 => _formatWithUnit(context, value, "m3", decimalDigits: 2, signMode: signMode),
    10 => _formatSpeed(context, value, signMode: signMode),
    11 => _formatWithUnit(context, value, "m/s^2", decimalDigits: 2, signMode: signMode),
    12 => _formatWithUnit(context, value, "m^-1", decimalDigits: 2, signMode: signMode),
    13 => _formatWithUnit(context, value, "kg/m3", decimalDigits: 2, signMode: signMode),
    14 => _formatWithUnit(context, value, "m3/kg", decimalDigits: 2, signMode: signMode),
    15 => _formatWithUnit(context, value, "A/m2", decimalDigits: 2, signMode: signMode),
    16 => _formatWithUnit(context, value, "A/m", decimalDigits: 2, signMode: signMode),
    17 => _formatWithUnit(context, value, "mol/m3", decimalDigits: 2, signMode: signMode),
    18 => _formatWithUnit(context, value, "cd/m2", decimalDigits: 2, signMode: signMode),
    19 => _formatWithUnit(context, value, "kg/kg", decimalDigits: 2, signMode: signMode),
    101 => _formatMilliseconds(context, value, signMode: signMode),
    102 => _formatWithUnit(context, value, "mm", decimalDigits: 0, signMode: signMode),
    103 => _formatWithUnit(context, value, "MPa", decimalDigits: 2, signMode: signMode),
    104 => _formatWithUnit(
      context,
      value,
      "x",
      decimalDigits: 2,
      signMode: signMode,
      spaceBeforeUnit: false,
    ),
    105 => _formatPercent(context, value, signMode: signMode),
    106 => _formatWithUnit(context, value, "tf", decimalDigits: 2, signMode: signMode),
    107 => _formatWithUnit(context, value, "MW", decimalDigits: 2, signMode: signMode),
    108 => _formatPercent(context, (1 - value) * 100, signMode: signMode),
    109 => _formatPercent(context, (value - 1) * 100, signMode: DogmaUnitSignMode.positive),
    111 => _formatPercent(context, (1 - value) * 100, signMode: signMode),
    112 => _formatWithUnit(context, value, "rad/s", decimalDigits: 3, signMode: signMode),
    113 => _formatWithUnit(context, value, "HP", decimalDigits: 2, signMode: signMode),
    114 => _formatWithUnit(context, value, "GJ", decimalDigits: 2, signMode: signMode),
    115 => _formatResolvedId(context, value, resolveGroupId, signMode: signMode),
    116 => _formatResolvedId(context, value, resolveTypeId, signMode: signMode),
    119 => _formatResolvedId(context, value, resolveAttributeId, signMode: signMode),
    143 => _formatInteger(context, value, signMode: signMode),
    117 => _formatSizeClass(context, value),
    118 || 138 => _formatWithUnit(
      context,
      value,
      dogmaUnitLabel(ref, unit),
      decimalDigits: 0,
      signMode: signMode,
    ),
    120 => _formatWithUnit(
      context,
      value,
      dogmaUnitLabel(ref, unit),
      decimalDigits: 0,
      signMode: signMode,
    ),
    121 => _formatPercent(context, value, signMode: signMode),
    122 => _formatInteger(context, value, signMode: signMode),
    124 => _formatPercent(context, value, signMode: signMode),
    125 => _formatWithUnit(context, value, "N", decimalDigits: 0, signMode: signMode),
    126 => _formatWithUnit(context, value, "ly", decimalDigits: 2, signMode: signMode),
    127 => _formatPercent(context, value * 100, signMode: signMode),
    128 => _formatWithUnit(context, value, "Mbit/s", decimalDigits: 0, signMode: signMode),
    129 => _formatHours(context, value, signMode: signMode),
    133 => _formatWithUnit(context, value, "ISK", decimalDigits: 2, signMode: signMode),
    134 => _formatWithUnit(context, value, "m3/h", decimalDigits: 0, signMode: signMode),
    135 => _formatWithUnit(context, value, "AU", decimalDigits: 3, signMode: signMode),
    136 => _formatPrefixedUnit(context, ref, unit, value, decimalDigits: 0, signMode: signMode),
    137 => value == 0 ? context.l10n.itemDetailBooleanFalse : context.l10n.itemDetailBooleanTrue,
    139 => _formatAdaptiveNumber(
      context,
      value,
      maxDecimalDigits: 2,
      signMode: DogmaUnitSignMode.positive,
    ),
    140 => _formatPrefixedUnit(context, ref, unit, value, decimalDigits: 0, signMode: signMode),
    141 => _formatWithUnit(
      context,
      value,
      dogmaUnitLabel(ref, unit),
      decimalDigits: 0,
      signMode: signMode,
    ),
    142 => _formatSex(context, value),
    144 => _formatWithUnit(context, value, "AU/s", decimalDigits: 2, signMode: signMode),
    205 => _formatPercent(context, value, signMode: DogmaUnitSignMode.positive),
    _ => _formatFallbackValue(context, ref, unit, value, signMode: signMode),
  };
}

String formatDogmaUnitDelta(
  BuildContext context,
  WidgetRef ref,
  DogmaUnit? unit, {
  required double baseValue,
  required double currentValue,
}) {
  if (!canFormatDogmaUnitDelta(unit)) return "";

  if (unit == null) {
    return formatDogmaUnitValue(
      context,
      ref,
      null,
      currentValue - baseValue,
      signMode: DogmaUnitSignMode.positive,
    );
  }

  return switch (unit.dogmaUnitId) {
    108 || 111 => _formatPercent(
      context,
      (1 - currentValue) * 100 - (1 - baseValue) * 100,
      signMode: DogmaUnitSignMode.positive,
    ),
    109 => _formatPercent(
      context,
      (currentValue - 1) * 100 - (baseValue - 1) * 100,
      signMode: DogmaUnitSignMode.positive,
    ),
    127 => _formatPercent(
      context,
      currentValue * 100 - baseValue * 100,
      signMode: DogmaUnitSignMode.positive,
    ),
    _ => formatDogmaUnitValue(
      context,
      ref,
      unit,
      currentValue - baseValue,
      signMode: DogmaUnitSignMode.positive,
    ),
  };
}

bool isBooleanDogmaUnit(DogmaUnit? unit) => unit?.dogmaUnitId == 137;

bool canFormatDogmaUnitDelta(DogmaUnit? unit) => switch (unit?.dogmaUnitId) {
  115 || 116 || 117 || 119 || 137 || 142 => false,
  _ => true,
};

String dogmaUnitLabel(WidgetRef ref, DogmaUnit unit) {
  final localized = unit.hasDisplayName()
      ? ref.watch(localizationProvider(unit.displayName.id))?.trim()
      : null;
  if (localized?.isNotEmpty ?? false) return localized!;
  return unit.name.trim();
}

String _formatDistance(BuildContext context, double meters, {required DogmaUnitSignMode signMode}) {
  final abs = meters.abs();
  if (abs >= _metersPerAu) {
    return _formatWithUnit(
      context,
      meters / _metersPerAu,
      "AU",
      decimalDigits: 3,
      signMode: signMode,
    );
  }
  if (abs >= 1000) {
    return _formatWithUnit(context, meters / 1000, "km", decimalDigits: 2, signMode: signMode);
  }
  return _formatWithUnit(context, meters, "m", decimalDigits: 0, signMode: signMode);
}

String _formatSpeed(BuildContext context, double value, {required DogmaUnitSignMode signMode}) {
  if (value.abs() >= 1000) {
    return _formatWithUnit(context, value / 1000, "km/s", decimalDigits: 2, signMode: signMode);
  }
  return _formatWithUnit(context, value, "m/s", decimalDigits: 2, signMode: signMode);
}

String _formatMilliseconds(
  BuildContext context,
  double milliseconds, {
  required DogmaUnitSignMode signMode,
}) {
  if (milliseconds.abs() < 1000) {
    return _formatWithUnit(context, milliseconds, "ms", decimalDigits: 2, signMode: signMode);
  }
  return _formatSeconds(context, milliseconds / 1000, signMode: signMode);
}

String _formatSeconds(BuildContext context, double seconds, {required DogmaUnitSignMode signMode}) {
  final abs = seconds.abs();
  if (abs >= 86400) {
    return _formatWithUnit(context, seconds / 86400, "d", decimalDigits: 2, signMode: signMode);
  }
  if (abs >= 3600) {
    return _formatWithUnit(context, seconds / 3600, "h", decimalDigits: 2, signMode: signMode);
  }
  if (abs >= 60) {
    return _formatWithUnit(context, seconds / 60, "min", decimalDigits: 2, signMode: signMode);
  }
  return _formatWithUnit(context, seconds, "s", decimalDigits: 2, signMode: signMode);
}

String _formatHours(BuildContext context, double hours, {required DogmaUnitSignMode signMode}) {
  if (hours.abs() >= 24) {
    return _formatWithUnit(context, hours / 24, "d", decimalDigits: 2, signMode: signMode);
  }
  return _formatWithUnit(context, hours, "h", decimalDigits: 2, signMode: signMode);
}

String _formatSizeClass(BuildContext context, double value) => switch (value.round()) {
  1 => context.l10n.dogmaUnitSizeSmall,
  2 => context.l10n.dogmaUnitSizeMedium,
  3 => context.l10n.dogmaUnitSizeLarge,
  4 => context.l10n.dogmaUnitSizeXLarge,
  _ => context.l10n.dogmaUnitSizeUnknown(value: _formatInteger(context, value)),
};

String _formatSex(BuildContext context, double value) => switch (value.round()) {
  1 => context.l10n.dogmaUnitSexMale,
  2 => context.l10n.dogmaUnitSexUnisex,
  3 => context.l10n.dogmaUnitSexFemale,
  _ => context.l10n.dogmaUnitSexUnknown(value: _formatInteger(context, value)),
};

String _formatResolvedId(
  BuildContext context,
  double value,
  DogmaUnitIdResolver? resolveId, {
  required DogmaUnitSignMode signMode,
}) {
  final id = value.round();
  if (value.isFinite && value == id.toDouble()) {
    final resolved = resolveId?.call(id)?.trim();
    if (resolved?.isNotEmpty ?? false) return resolved!;
  }
  return _formatInteger(context, value, signMode: signMode);
}

String _formatPrefixedUnit(
  BuildContext context,
  WidgetRef ref,
  DogmaUnit unit,
  double value, {
  required int decimalDigits,
  required DogmaUnitSignMode signMode,
}) {
  final label = dogmaUnitLabel(ref, unit);
  final formatted = _formatFixedNumber(context, value, decimalDigits, signMode: signMode);
  if (label.isEmpty) return formatted;
  return "$label $formatted";
}

String _formatFallbackValue(
  BuildContext context,
  WidgetRef ref,
  DogmaUnit unit,
  double value, {
  required DogmaUnitSignMode signMode,
}) {
  final label = dogmaUnitLabel(ref, unit);
  final formatted = _formatAdaptiveNumber(context, value, maxDecimalDigits: 3, signMode: signMode);
  if (label.isEmpty) return formatted;
  return "$formatted $label";
}

String _formatPercent(BuildContext context, double value, {required DogmaUnitSignMode signMode}) =>
    "${_formatAdaptiveNumber(context, value, maxDecimalDigits: 2, signMode: signMode)}%";

String _formatWithUnit(
  BuildContext context,
  double value,
  String unit, {
  required int decimalDigits,
  DogmaUnitSignMode signMode = DogmaUnitSignMode.none,
  bool spaceBeforeUnit = true,
}) {
  final formatted = _formatFixedNumber(context, value, decimalDigits, signMode: signMode);
  if (unit.isEmpty) return formatted;
  return spaceBeforeUnit ? "$formatted $unit" : "$formatted$unit";
}

String _formatInteger(
  BuildContext context,
  double value, {
  DogmaUnitSignMode signMode = DogmaUnitSignMode.none,
}) => _formatFixedNumber(context, value, 0, signMode: signMode);

String _formatFixedNumber(
  BuildContext context,
  double value,
  int decimalDigits, {
  required DogmaUnitSignMode signMode,
}) {
  final normalized = _normalizeZero(value, decimalDigits);
  final format = intl.NumberFormat.decimalPattern(context.locale.toString())
    ..minimumFractionDigits = decimalDigits
    ..maximumFractionDigits = decimalDigits;
  return "${_positivePrefix(normalized, signMode)}${format.format(normalized)}";
}

String _formatAdaptiveNumber(
  BuildContext context,
  double value, {
  required int maxDecimalDigits,
  required DogmaUnitSignMode signMode,
}) {
  final normalized = _normalizeZero(value, maxDecimalDigits);
  final format = intl.NumberFormat.decimalPattern(context.locale.toString())
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = maxDecimalDigits;
  return "${_positivePrefix(normalized, signMode)}${format.format(normalized)}";
}

String _positivePrefix(double value, DogmaUnitSignMode signMode) =>
    signMode == DogmaUnitSignMode.positive && value > 0 ? "+" : "";

double _normalizeZero(double value, int decimalDigits) {
  final threshold = 0.5 / math.pow(10, decimalDigits);
  return value.abs() < threshold ? 0 : value;
}
