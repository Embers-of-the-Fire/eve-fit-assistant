import 'package:eve_fit_assistant/assets/assets.dart';
import 'package:eve_fit_assistant/native/glue/native_slot.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/pages/fit/panel/native_error.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/static/ships.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

List<Widget> getEquipmentHeader({
  required String fitID,
  required Ship ship,
  required FitItemType type,
}) =>
    [
      EquipmentHeaderText(
        fitID: fitID,
        ship: ship,
        type: type,
        padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 4),
      ),
      const Divider(height: 8),
      EquipmentHeaderOperation(fitID: fitID, ship: ship, type: type),
      const Divider(height: 4),
    ];

class EquipmentHeaderOperation extends ConsumerWidget {
  final String fitID;
  final Ship ship;
  final FitItemType type;

  const EquipmentHeaderOperation({
    super.key,
    required this.fitID,
    required this.type,
    required this.ship,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.watch(fitRecordNotifierProvider(fitID).notifier);

    final List<InkWell> ops = [];

    final Function(FitRecord)? clearSlot = switch (type) {
      FitItemType.high => (r) => r.clearHigh(),
      FitItemType.med => (r) => r.clearMed(),
      FitItemType.low => (r) => r.clearLow(),
      FitItemType.rig => (r) => r.clearRig(),
      FitItemType.subsystem => (r) => r.clearSubsystem(),
      _ => null,
    };
    if (clearSlot != null) {
      ops.add(InkWell(
        onTap: () => fitNotifier.modify((record) {
          final _ = clearSlot(record);
          return record;
        }),
        child: const Icon(Icons.clear_all),
      ));
    }

    final Function(FitRecord)? clearCharge = switch (type) {
      FitItemType.high => (r) => r.clearHighCharge(),
      FitItemType.med => (r) => r.clearMedCharge(),
      FitItemType.low => (r) => r.clearLowCharge(),
      FitItemType.rig => (r) => r.clearRigCharge(),
      _ => null,
    };

    if (clearCharge != null) {
      ops.add(InkWell(
        onTap: () => fitNotifier.modify((record) {
          final _ = clearCharge(record);
          return record;
        }),
        child: const Icon(Icons.battery_alert_outlined),
      ));
    }

    return Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
        child: Row(spacing: 10, children: ops));
  }
}

class EquipmentHeaderText extends ConsumerWidget {
  final String fitID;
  final Ship ship;
  final FitItemType type;
  final EdgeInsets? padding;

  const EquipmentHeaderText({
    super.key,
    required this.fitID,
    required this.type,
    required this.ship,
    this.padding,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(fitRecordNotifierProvider(fitID));
    final fitBody = fit.fit.body;

    final errors = fit.output.errors
        .filter((e) => e.slot.fitItemType == type && e.index == null)
        .toList(growable: false);

    switch (type) {
      case FitItemType.high:
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

        return ListTile(
          minVerticalPadding: 0,
          minTileHeight: 0,
          contentPadding: padding,
          title: const Text('高能量槽'),
          trailing: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(TextSpan(
                children: [
                  const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Image(image: weaponTurretNumImage, height: 22)),
                  TextSpan(
                    text: ' $sumTurret/$allTurret',
                    style: TextStyle(
                      color: allTurret == 0
                          ? Colors.white
                          : sumTurret.compareTo(allTurret).when(
                                zero: () => Colors.green,
                                positive: () => Colors.red,
                                negative: () => Colors.orange,
                              ),
                      fontSize: 14,
                    ),
                  ),
                  const WidgetSpan(child: SizedBox(width: 15)),
                  const WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Image(image: weaponLauncherNumImage, height: 22)),
                  TextSpan(
                    text: ' $sumLauncher/$allLauncher',
                    style: TextStyle(
                      color: allLauncher == 0
                          ? Colors.white
                          : sumLauncher.compareTo(allLauncher).when(
                                zero: () => Colors.green,
                                positive: () => Colors.red,
                                negative: () => Colors.orange,
                              ),
                      fontSize: 14,
                    ),
                  ),
                ],
              )),
              ...errors.isNotEmpty
                  ? [const SizedBox(width: 10), NativeErrorTrigger(errors: errors)]
                  : [],
            ],
          ),
        );
      case _:
        return ListTile(
          minVerticalPadding: 0,
          minTileHeight: 0,
          contentPadding: padding,
          title: Text(_getSlotName(type)),
          trailing: errors.isNotEmpty ? NativeErrorTrigger(errors: errors) : null,
        );
    }
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
