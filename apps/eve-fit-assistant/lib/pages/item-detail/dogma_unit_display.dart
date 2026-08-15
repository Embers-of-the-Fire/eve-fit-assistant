import "dart:math" as math;

import "package:efa_constant/eve.dart";
import "package:efa_proto/dogma_units.pb.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
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

  return switch (EveDogmaUnitId.fromId(unit.dogmaUnitId)) {
    EveDogmaUnitId.length => _formatDistance(context, value, signMode: signMode),
    EveDogmaUnitId.mass => _formatWithUnit(
      context,
      value,
      "kg",
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.time ||
    EveDogmaUnitId.trueTime => _formatSeconds(context, value, signMode: signMode),
    EveDogmaUnitId.electricCurrent => _formatWithUnit(
      context,
      value,
      "A",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.temperature => _formatWithUnit(
      context,
      value,
      "K",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.amountOfSubstance => _formatWithUnit(
      context,
      value,
      "mol",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.luminousIntensity => _formatWithUnit(
      context,
      value,
      "cd",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.area => _formatWithUnit(
      context,
      value,
      "m2",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.volume => _formatWithUnit(
      context,
      value,
      "m3",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.speed => _formatSpeed(context, value, signMode: signMode),
    EveDogmaUnitId.acceleration => _formatWithUnit(
      context,
      value,
      "m/s^2",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.waveNumber => _formatWithUnit(
      context,
      value,
      "m^-1",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.massDensity => _formatWithUnit(
      context,
      value,
      "kg/m3",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.specificVolume => _formatWithUnit(
      context,
      value,
      "m3/kg",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.currentDensity => _formatWithUnit(
      context,
      value,
      "A/m2",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.magneticFieldStrength => _formatWithUnit(
      context,
      value,
      "A/m",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.amountOfSubstanceConcentration => _formatWithUnit(
      context,
      value,
      "mol/m3",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.luminance => _formatWithUnit(
      context,
      value,
      "cd/m2",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.massFraction => _formatWithUnit(
      context,
      value,
      "kg/kg",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.milliseconds => _formatMilliseconds(context, value, signMode: signMode),
    EveDogmaUnitId.millimeters => _formatWithUnit(
      context,
      value,
      "mm",
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.megaPascals => _formatWithUnit(
      context,
      value,
      "MPa",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.multiplier => _formatWithUnit(
      context,
      value,
      "x",
      decimalDigits: 2,
      signMode: signMode,
      spaceBeforeUnit: false,
    ),
    EveDogmaUnitId.percentage => _formatPercent(context, value, signMode: signMode),
    EveDogmaUnitId.teraflops => _formatWithUnit(
      context,
      value,
      "tf",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.megaWatts => _formatWithUnit(
      context,
      value,
      "MW",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.inverseAbsolutePercent => _formatPercent(
      context,
      (1 - value) * 100,
      signMode: signMode,
    ),
    EveDogmaUnitId.modifierPercent => _formatPercent(
      context,
      (value - 1) * 100,
      signMode: DogmaUnitSignMode.positive,
    ),
    EveDogmaUnitId.inversedModifierPercent => _formatPercent(
      context,
      (1 - value) * 100,
      signMode: signMode,
    ),
    EveDogmaUnitId.radiansSecond => _formatWithUnit(
      context,
      value,
      "rad/s",
      decimalDigits: 3,
      signMode: signMode,
    ),
    EveDogmaUnitId.hitpoints => _formatWithUnit(
      context,
      value,
      "HP",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.capacitorUnits => _formatWithUnit(
      context,
      value,
      "GJ",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.groupId => _formatResolvedId(context, value, resolveGroupId, signMode: signMode),
    EveDogmaUnitId.typeId => _formatResolvedId(context, value, resolveTypeId, signMode: signMode),
    EveDogmaUnitId.attributeId => _formatResolvedId(
      context,
      value,
      resolveAttributeId,
      signMode: signMode,
    ),
    EveDogmaUnitId.datetime => _formatInteger(context, value, signMode: signMode),
    EveDogmaUnitId.sizeclass => _formatSizeClass(context, value),
    EveDogmaUnitId.oreUnits || EveDogmaUnitId.units => _formatWithUnit(
      context,
      value,
      dogmaUnitLabel(ref, unit),
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.attributePoints => _formatWithUnit(
      context,
      value,
      dogmaUnitLabel(ref, unit),
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.realPercent => _formatPercent(context, value, signMode: signMode),
    EveDogmaUnitId.fittingSlots => _formatInteger(context, value, signMode: signMode),
    EveDogmaUnitId.modifierRelativePercent => _formatPercent(context, value, signMode: signMode),
    EveDogmaUnitId.newton => _formatWithUnit(
      context,
      value,
      "N",
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.lightYear => _formatWithUnit(
      context,
      value,
      "ly",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.absolutePercent => _formatPercent(context, value * 100, signMode: signMode),
    EveDogmaUnitId.droneBandwidth => _formatWithUnit(
      context,
      value,
      "Mbit/s",
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.hours => _formatHours(context, value, signMode: signMode),
    EveDogmaUnitId.money => _formatWithUnit(
      context,
      value,
      "ISK",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.logisticalCapacity => _formatWithUnit(
      context,
      value,
      "m3/h",
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.astronomicalUnit => _formatWithUnit(
      context,
      value,
      "AU",
      decimalDigits: 3,
      signMode: signMode,
    ),
    EveDogmaUnitId.slot => _formatPrefixedUnit(
      context,
      ref,
      unit,
      value,
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.boolean =>
      value == 0 ? context.l10n.itemDetailBooleanFalse : context.l10n.itemDetailBooleanTrue,
    EveDogmaUnitId.bonus => _formatAdaptiveNumber(
      context,
      value,
      maxDecimalDigits: 2,
      signMode: DogmaUnitSignMode.positive,
    ),
    EveDogmaUnitId.level => _formatPrefixedUnit(
      context,
      ref,
      unit,
      value,
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.hardpoints => _formatWithUnit(
      context,
      value,
      dogmaUnitLabel(ref, unit),
      decimalDigits: 0,
      signMode: signMode,
    ),
    EveDogmaUnitId.sex => _formatSex(context, value),
    EveDogmaUnitId.warpSpeed => _formatWithUnit(
      context,
      value,
      "AU/s",
      decimalDigits: 2,
      signMode: signMode,
    ),
    EveDogmaUnitId.modifierRealPercent => _formatPercent(
      context,
      value,
      signMode: DogmaUnitSignMode.positive,
    ),
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

  return switch (EveDogmaUnitId.fromId(unit.dogmaUnitId)) {
    EveDogmaUnitId.inverseAbsolutePercent ||
    EveDogmaUnitId.inversedModifierPercent => _formatPercent(
      context,
      (1 - currentValue) * 100 - (1 - baseValue) * 100,
      signMode: DogmaUnitSignMode.positive,
    ),
    EveDogmaUnitId.modifierPercent => _formatPercent(
      context,
      (currentValue - 1) * 100 - (baseValue - 1) * 100,
      signMode: DogmaUnitSignMode.positive,
    ),
    EveDogmaUnitId.absolutePercent => _formatPercent(
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

bool isBooleanDogmaUnit(DogmaUnit? unit) => _dogmaUnitId(unit) == EveDogmaUnitId.boolean;

bool canFormatDogmaUnitDelta(DogmaUnit? unit) => switch (_dogmaUnitId(unit)) {
  EveDogmaUnitId.groupId ||
  EveDogmaUnitId.typeId ||
  EveDogmaUnitId.sizeclass ||
  EveDogmaUnitId.attributeId ||
  EveDogmaUnitId.boolean ||
  EveDogmaUnitId.sex => false,
  _ => true,
};

EveDogmaUnitId? _dogmaUnitId(DogmaUnit? unit) =>
    unit == null ? null : EveDogmaUnitId.fromId(unit.dogmaUnitId);

String dogmaUnitLabel(WidgetRef ref, DogmaUnit unit) {
  final locale = ref.watch(localeProvider).name;
  final localized = unit.hasDisplayName()
      ? watchLocalizedName(ref, id: unit.displayName.id, locale: locale)?.trim()
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
