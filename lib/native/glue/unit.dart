import 'package:eve_fit_assistant/native/codegen/constant/unit.dart';
import 'package:eve_fit_assistant/storage/static/units.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

extension UnitExt on UnitType {
  UnitItem get unitItem => GlobalStorage().static.units[id]!;

  String format(double value) => switch (this) {
        UnitType.massFraction => '${(value).toStringAsMaxDecimals(2)} kg/kg',
        UnitType.milliseconds => value > 1000
            ? '${(value / 1000).toStringAsMaxDecimals(2)} s'
            : '${value.toStringAsMaxDecimals(0)} ms',
        UnitType.millimeters => '${(value).toStringAsFixed(0)} mm',
        UnitType.megaPascals => '${(value).toStringAsMaxDecimals(2)} MPa',
        UnitType.inverseAbsolutePercent ||
        UnitType.inversedModifierPercent =>
          '${((1 - value) * 100).toStringAsFixed(0)} %',
        UnitType.modifierPercent =>
          '${value >= 1 ? '+' : ''}${((value - 1) * 100).toStringAsFixed(0)} %',
        UnitType.oreUnits || UnitType.fittingSlots || UnitType.slot => value.toStringAsFixed(0),
        UnitType.groupId =>
          GlobalStorage().static.groups[value.toInt()]?.nameZH ?? value.toStringAsFixed(0),
        UnitType.typeId =>
          GlobalStorage().static.types[value.toInt()]?.nameZH ?? value.toStringAsFixed(0),
        UnitType.attributeId => GlobalStorage().static.attributes[value.toInt()]?.displayNameZH ??
            value.toStringAsFixed(0),
        UnitType.sizeclass => switch (value) {
            1 => '小型',
            2 => '中型',
            3 => '大型',
            4 => '超大型',
            _ => '未知',
          },
        UnitType.absolutePercent => '${(value * 100).toStringAsMaxDecimals(2)} %',
        UnitType.droneBandwidth => '${value.toStringAsMaxDecimals(0)} Mbit/s',
        UnitType.hours => '${value.toStringAsFixed(0)} h',
        UnitType.money => '${value.toStringAsMaxDecimals(2)} ISK',
        UnitType.logisticalCapacity => '${value.toStringAsMaxDecimals(2)} m3/h',
        UnitType.boolean => value == 1 ? '是' : '否',
        UnitType.units => value.toStringAsFixed(0),
        UnitType.level => 'Lv. ${value.toStringAsFixed(0)}',
        UnitType.hardpoints => value.toStringAsFixed(0),
        UnitType.sex => switch (value) {
            1 => '男性',
            2 => '中性',
            3 => '女性',
            _ => '未知',
          },
        UnitType.datetime => fromSecondsSinceEpoch(value.toInt()).toString(),
        UnitType.modifierRealPercent =>
          '${value >= 0 ? '+' : ''}${value.toStringAsMaxDecimals(2)} %',
        _ => '${value.toStringAsMaxDecimals(2)} ${unitItem.displayName}',
      };
}
