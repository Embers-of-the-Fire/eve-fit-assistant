import 'dart:ui';

import 'package:eve_fit_assistant/assets/assets.dart';
import 'package:eve_fit_assistant/constant/eve/attribute.dart';
import 'package:eve_fit_assistant/native/glue/fit.dart';
import 'package:eve_fit_assistant/native/glue/native_slot.dart';
import 'package:eve_fit_assistant/native/port/api/proxy.dart';
import 'package:eve_fit_assistant/native/port/api/schema.dart' as schema;
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/pages/fit/panel/info/info_component.dart';
import 'package:eve_fit_assistant/pages/fit/panel/native_error.dart';
import 'package:eve_fit_assistant/pages/fit/panel/slot.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/static/ship_subsystems.dart';
import 'package:eve_fit_assistant/storage/static/ships.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/resonance_box.dart';
import 'package:eve_fit_assistant/widgets/state_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

part 'drones.dart';
part 'slots.dart';
part 'static_info.dart';

class FitStaticDisplay extends StatelessWidget {
  final bool displayEhp;
  final Ship ship;
  final FitRecordState fit;

  FitStaticDisplay({
    super.key,
    required this.displayEhp,
    required this.ship,
    required this.fit,
  });

  final GlobalKey _paintKey = GlobalKey();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('保存装配图片'),
        ),
        body: SafeArea(
            bottom: true,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ElevatedButton(
                      onPressed: () async {
                        final boundary =
                            _paintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                        final dpr = View.of(context).devicePixelRatio;
                        final image = await boundary!.toImage(pixelRatio: dpr);
                        final bytes = await image.toByteData(format: ImageByteFormat.png);
                        await ImageGallerySaverPlus.saveImage(bytes!.buffer.asUint8List());
                      },
                      child: const Text('保存为图片'))),
              const Divider(),
              Expanded(
                  child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: RepaintBoundary(
                              key: _paintKey,
                              child: Container(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                width: MediaQuery.of(context).size.width * 3,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _FitStaticCharacter(fit: fit)),
                                    Expanded(child: _FitStaticEquipment(ship: ship, fit: fit)),
                                    Expanded(
                                        child: _FitStaticInfo(
                                            ship: ship, fit: fit, displayEhp: displayEhp)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )))
            ])),
      );
}

ListTile _getHeader({required Widget title, Widget? trailing}) => ListTile(
      minTileHeight: 0,
      minVerticalPadding: 0,
      contentPadding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 4),
      title: title,
      trailing: trailing,
    );

class _FitStaticCharacter extends StatelessWidget {
  final FitRecordState fit;

  const _FitStaticCharacter({required this.fit});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: const Icon(Icons.account_circle, size: 30),
            ),
            title: Text(fit.character.name),
          ),
          const Divider(height: 0),
          _getHeader(title: const Text('植入体')),
          const Divider(height: 0),
          ...fit.fit.body.implant.enumerate().filterMap((t) =>
              t.$2.map((i) => _getStaticSlotRow(fit, i, type: FitItemType.implant, index: t.$1))),
          _getHeader(title: const Text('增效剂')),
          const Divider(height: 0),
          ...fit.fit.body.booster
              .enumerate()
              .map((t) => _StaticBoosterSlotDisplay(fit: fit, index: t.$1))
        ],
      );
}

class _FitStaticEquipment extends StatelessWidget {
  final Ship ship;
  final FitRecordState fit;

  const _FitStaticEquipment({required this.ship, required this.fit});

  List<Widget> _getEquipmentHeader({
    required FitItemType type,
  }) {
    final errors = fit.output.errors
        .filter((e) => e.slot.fitItemType == type && e.index == null)
        .toList(growable: false);

    late final Widget body;
    switch (type) {
      case FitItemType.high:
        final sumTurret = fit.fit.body.high
            .filterMap((item) => item)
            .filterMap((item) => GlobalStorage().static.typeSlot.high[item.itemID])
            .filter((item) => item.isTurret)
            .count();
        final sumLauncher = fit.fit.body.high
            .filterMap((item) => item)
            .filterMap((item) => GlobalStorage().static.typeSlot.high[item.itemID])
            .filter((item) => item.isLauncher)
            .count();

        final allTurret = ship.turretSlotNum +
            fit.fit.body.subsystem
                .filterMap((u) => u?.itemID)
                .filterMap((item) => GlobalStorage().static.subsystems.items[item]?.turret)
                .sum();
        final allLauncher = ship.launcherSlotNum +
            fit.fit.body.subsystem
                .filterMap((u) => u?.itemID)
                .filterMap((item) => GlobalStorage().static.subsystems.items[item]?.launcher)
                .sum();

        body = _getHeader(
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
        body = _getHeader(
          title: Text(switch (type) {
            FitItemType.high => '高能量槽',
            FitItemType.med => '中能量槽',
            FitItemType.low => '低能量槽',
            FitItemType.rig => '改装件',
            FitItemType.subsystem => '子系统',
            FitItemType.drone => '无人机',
            FitItemType.fighter => '铁骑舰载机',
            _ => '未知',
          }),
          trailing: errors.isNotEmpty ? NativeErrorTrigger(errors: errors) : null,
        );
    }
    return [
      body,
      const Divider(height: 4),
    ];
  }

  // @override
  // Widget build(BuildContext context) => const Text('123');

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...fit.fit.body.tacticalModeID == null
              ? []
              : [
                  const ListTile(title: Text('战术模式')),
                  _StaticTacticalModeSlotRowDisplay(
                    shipID: fit.fit.body.shipID,
                    modeID: fit.fit.body.tacticalModeID!,
                  )
                ],
          ..._getEquipmentHeader(type: FitItemType.high),
          ...fit.fit.body.high.enumerate().filterMap((t) =>
              t.$2.map((i) => _getStaticSlotRow(fit, i, type: FitItemType.high, index: t.$1))),
          ..._getEquipmentHeader(type: FitItemType.med),
          ...fit.fit.body.med.enumerate().filterMap((t) =>
              t.$2.map((i) => _getStaticSlotRow(fit, i, type: FitItemType.med, index: t.$1))),
          ..._getEquipmentHeader(type: FitItemType.low),
          ...fit.fit.body.low.enumerate().filterMap((t) =>
              t.$2.map((i) => _getStaticSlotRow(fit, i, type: FitItemType.low, index: t.$1))),
          ..._getEquipmentHeader(type: FitItemType.rig),
          ...fit.fit.body.rig.enumerate().filterMap((t) =>
              t.$2.map((i) => _getStaticSlotRow(fit, i, type: FitItemType.rig, index: t.$1))),
          ...(fit.fit.body.subsystem.countNonNull() > 0)
              .then(() => _getEquipmentHeader(
                    type: FitItemType.subsystem,
                  ))
              .unwrapOr([]),
          ...fit.fit.body.subsystem.enumerate().filterMap((t) => t.$2.map((i) => _getStaticSlotRow(
                fit,
                i,
                type: FitItemType.subsystem,
                index: t.$1,
              ))),
          ...(fit.output.ship.hull.attributes[droneBandwidth] ?? 0) > 0
              ? [
                  ..._getEquipmentHeader(type: FitItemType.drone),
                  ...fit.fit.body.drone.map((t) => _StaticDroneSlotDisplay(
                        droneID: t.itemID,
                        amount: t.amount,
                        state: t.state,
                      )),
                ]
              : [],
          ...ship.hasFighter ? [
            ..._getEquipmentHeader(type: FitItemType.fighter),
            ...fit.fit.body.fighter.enumerate().filterMap((t) => t.$2.map((i) =>
                _StaticFighterSlotDisplay(
                  fit: fit,
                  index: t.$1,
                  fighterID: i.itemID,
                  amount: i.amount,
                  state: i.state,
                  ability: i.ability,
                ))),
          ] : [],
        ],
      );
}

class _FitStaticInfo extends StatelessWidget {
  final bool displayEhp;
  final Ship ship;
  final FitRecordState fit;

  const _FitStaticInfo({required this.displayEhp, required this.ship, required this.fit});

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minVerticalPadding: 10,
          minTileHeight: 0,
          leading: GlobalStorage().static.icons.getTypeIconSync(fit.fit.brief.shipID),
          title: Text(ship.nameZH, textAlign: TextAlign.center),
        ),
        const Divider(height: 0),
        Capacitor(ship: fit.output.ship),
        Weapon(ship: fit.output.ship),
        Resource(ship: fit.output.ship),
        _StaticHpTable(fit: fit, displayEhp: displayEhp),
        Extra(ship: fit.output.ship),
        Cargo(ship: fit.output.ship),
      ]);
}
