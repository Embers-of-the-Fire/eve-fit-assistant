import 'package:eve_fit_assistant/native/glue/native_slot.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/pages/fit/panel/native_error.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/static/ships.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EquipmentHeader extends ConsumerWidget {
  final String fitID;
  final Ship ship;
  final FitItemType type;

  const EquipmentHeader({
    super.key,
    required this.fitID,
    required this.type,
    required this.ship,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(fitRecordNotifierProvider(fitID));
    final fitBody = fit.fit.body;

    final errors = fit.output.errors
        .filter((e) => e.slot.fitItemType == type && e.index == null)
        .toList(growable: false);

    final sumTurret = fitBody.high
        .filterMap((item) => item)
        .filterMap((item) => GlobalStorage().static.typeSlot.high[item.itemID])
        .filter((item) => item.isTurret)
        .count();
    final sumLauncher = fitBody.high
        .filterMap((item) => item)
        .filterMap((item) => GlobalStorage().static.typeSlot.high[item.itemID])
        .filter((item) => item.isLauncher)
        .count();

    final allTurret = ship.turretSlotNum +
        fitBody.subsystem
            .filterMap((u) => u?.itemID)
            .filterMap((item) => GlobalStorage().static.subsystems.items[item]?.turret)
            .sum();
    final allLauncher = ship.launcherSlotNum +
        fitBody.subsystem
            .filterMap((u) => u?.itemID)
            .filterMap((item) => GlobalStorage().static.subsystems.items[item]?.launcher)
            .sum();

    return switch (type) {
      FitItemType.high => ListTile(
          title: const Text('高能量槽'),
          trailing: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '炮塔 $sumTurret/$allTurret'
                ' | 发射器 $sumLauncher/$allLauncher',
                style: const TextStyle(fontSize: 14),
              ),
              ...errors.isNotEmpty
                  ? [const SizedBox(width: 10), NativeErrorTrigger(errors: errors)]
                  : [],
            ],
          ),
        ),
      _ => ListTile(
          title: Text(_getSlotName(type)),
          trailing: errors.isNotEmpty ? NativeErrorTrigger(errors: errors) : null,
        ),
    };
  }
}

String _getSlotName(FitItemType type) => switch (type) {
      FitItemType.high => '高能量槽',
      FitItemType.med => '中能量槽',
      FitItemType.low => '低能量槽',
      FitItemType.rig => '改装件',
      FitItemType.subsystem => '子系统',
      _ => '未知',
    };
