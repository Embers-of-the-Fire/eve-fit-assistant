part of 'display.dart';

class _StaticSlotRowDisplay extends StatelessWidget {
  final FitRecordState fit;
  final int index;
  final int typeID;
  final int? chargeID;
  final FitItemType type;
  final SlotState state;

  const _StaticSlotRowDisplay({
    required this.fit,
    required this.index,
    required this.typeID,
    required this.chargeID,
    required this.type,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final List<ItemProxy> slots = fit.output.ship.getSlots(type);
    final ItemProxy? item = slots.find((item) => item.index == index);

    final List<List<Widget>> subtitleGroup = [];

    {
      // charge
      final List<Widget> row = [];

      if (chargeID != null) {
        final chargeNum = item?.attributes[chargeAmount]?.toInt();
        if (chargeNum != null) {
          row.add(Text('$chargeNum× ', style: const TextStyle(fontSize: 14)));
          row.add(const SizedBox(width: 4));
        }
        final icon = GlobalStorage().static.icons.getTypeIconSync(chargeID!, width: 18, height: 18);
        if (icon != null) {
          row.add(icon);
          row.add(const SizedBox(width: 4));
        }
        final chargeName = GlobalStorage().static.types[chargeID!]?.nameZH ?? '未知';
        row.add(Text(chargeName, style: const TextStyle(fontSize: 14)));
      }

      if (row.isNotEmpty) {
        subtitleGroup.add(row);
      }
    }

    if (item != null) {
      final List<Widget> row = [];

      // fire range
      final range = item.attributes[maxRange];
      if (range != null && range > 0) {
        // turret
        row.add(const Image(image: targetRangeImage, width: 18, height: 18));
        row.add(const SizedBox(width: 4));
        String text = '${(range / 1000).toStringAsMaxDecimals(1)} km';

        final extraRange = item.attributes[falloff];
        if (extraRange != null && extraRange > 0) {
          text += ' + ${(extraRange / 1000).toStringAsMaxDecimals(1)} km';
        }

        final extraEffectRange = item.attributes[falloffEffectiveness];
        if (extraEffectRange != null && extraEffectRange > 0) {
          text += ' + ${(extraEffectRange / 1000).toStringAsMaxDecimals(1)} km';
        }

        row.add(Text(text, style: const TextStyle(fontSize: 14)));
      } else if (item.charge != null) {
        // missile launcher
        final charge = item.charge!;
        final speed = charge.attributes[maxVelocity] ?? 0.0;
        final time = charge.attributes[explosionDelay] ?? 0.0;
        final range = speed * time / 1000_000;
        if (range > 0) {
          row.add(const Image(image: targetRangeImage, width: 18, height: 18));
          row.add(const SizedBox(width: 4));
          row.add(
              Text('${range.toStringAsMaxDecimals(1)} km', style: const TextStyle(fontSize: 14)));
        }
      } else {
        final effectRange = item.attributes[empFieldRange];
        if (effectRange != null) {
          row.add(const Image(image: targetRangeImage, width: 18, height: 18));
          row.add(const SizedBox(width: 4));
          row.add(Text(
            '${(effectRange / 1000).toStringAsMaxDecimals(1)} km',
            style: const TextStyle(fontSize: 14),
          ));
        }
      }

      // capacity
      final time = item.attributes[cycleTime];
      if (time != null && time > 0) {
        final capNeed = item.attributes[capacitorNeed] ?? 0;
        final capPerSecond = capNeed / time * 1000;
        if (capPerSecond > 0.001) {
          if (row.isNotEmpty) row.add(const SizedBox(width: 10));
          row.add(const Image(image: capacitorChargeImage, width: 18, height: 18));
          row.add(const SizedBox(width: 4));
          row.add(Text(
            '${capPerSecond.toStringAsMaxDecimals(1)} GJ/s',
            style: const TextStyle(fontSize: 14),
          ));
        }
      }

      if (row.isNotEmpty) {
        subtitleGroup.add(row);
      }
    }

    final errors = fit.output.errors
        .filter((err) => err.slot.fitItemType == type && err.index == index)
        .toList();

    return ListTile(
      leading: StateIcon(
        state: ItemState.fromInt(state.state),
        foregroundImage: GlobalStorage().static.icons.getTypeIconFileImageSync(typeID),
      ),
      title: Text(GlobalStorage().static.types[typeID]?.nameZH ?? '未知'),
      subtitle: subtitleGroup.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subtitleGroup.map((group) => Row(children: group)).toList(),
            ),
      trailing: errors.isNotEmpty ? NativeErrorStaticIndicator(errors: errors) : null,
    );
  }
}

// class _StaticSlotRowPlaceholderDisplay extends StatelessWidget {
//   final FitRecordState fit;
//   final FitItemType type;
//   final int index;
//
//   const _StaticSlotRowPlaceholderDisplay({
//     required this.fit,
//     required this.type,
//     required this.index,
//   });
//
//   @override
//   Widget build(BuildContext context) => ListTile(
//         leading: BorderedCircleAvatar(
//           size: 35,
//           backgroundColor: colorStatusPassive,
//           borderColor: colorStatusPassive,
//           image: switch (type) {
//             FitItemType.high => highPlaceholderImage,
//             FitItemType.med => mediumPlaceholderImage,
//             FitItemType.low => lowPlaceholderImage,
//             FitItemType.rig => rigPlaceholderImage,
//             _ => null
//           },
//           icon: switch (type) {
//             FitItemType.implant => Icons.add_circle_outline,
//             _ => null,
//           },
//         ),
//         title: Text(switch (type) { FitItemType.implant => '无植入体', _ => '无装备' }),
//         trailing: Text('${index + 1}'),
//       );
// }

class _StaticSubsystemSlotRowDisplay extends StatelessWidget {
  final FitRecordState fit;
  final int typeID;
  final SubsystemType type;

  const _StaticSubsystemSlotRowDisplay({
    required this.fit,
    required this.typeID,
    required this.type,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: StateIcon(
          state: ItemState.online,
          foregroundImage: GlobalStorage().static.icons.getTypeIconFileImageSync(typeID)!,
        ),
        title: Text(GlobalStorage().static.types[typeID]?.nameZH ?? '未知'),
      );
}

// class _StaticSubsystemSlotRowPlaceholderDisplay extends StatelessWidget {
//   final SubsystemType type;
//
//   const _StaticSubsystemSlotRowPlaceholderDisplay({
//     required this.type,
//   });
//
//   @override
//   Widget build(BuildContext context) => ListTile(
//         leading: StateIcon(
//             state: ItemState.online,
//             foregroundImage: switch (type) {
//               SubsystemType.offensive => subsystemOffensivePlaceholderImage,
//               SubsystemType.defensive => subsystemDefensivePlaceholderImage,
//               SubsystemType.core => subsystemCorePlaceholderImage,
//               SubsystemType.propulsion => subsystemPropulsionPlaceholderImage,
//             }),
//         title: const Text('子系统'),
//       );
// }

Widget _getStaticSlotRow(
  FitRecordState fit,
  SlotItem item, {
  required FitItemType type,
  required int index,
}) {
  if (type == FitItemType.subsystem) {
    final subType = SubsystemType.values[index];
      return _StaticSubsystemSlotRowDisplay(fit: fit, typeID: item.itemID, type: subType);
  }

  return _StaticSlotRowDisplay(
    fit: fit,
    index: index,
    typeID: item.isDynamic ? fit.fit.body.dynamicItems[item.itemID]!.outType : item.itemID,
    chargeID: item.chargeID,
    type: type,
    state: item.state,
  );
}

class _StaticTacticalModeSlotRowDisplay extends StatelessWidget {
  final int shipID;
  final int modeID;

  const _StaticTacticalModeSlotRowDisplay({
    required this.shipID,
    required this.modeID,
  });

  @override
  Widget build(BuildContext context) {
    final modeInfo = GlobalStorage().static.tacticalModes[shipID]?.tacticalModes[modeID];
    final modeImage =
        modeInfo.andThen((info) => GlobalStorage().static.icons.getIconFileImageSync(info.iconID));
    final typeName = modeInfo?.nameZH ?? '未知模式';

    return ListTile(
      leading: StateIcon(
        state: ItemState.active,
        foregroundImage: modeImage,
      ),
      title: Text(typeName),
    );
  }
}

class _StaticBoosterSlotDisplay extends StatelessWidget {
  final FitRecordState fit;
  final int index;

  const _StaticBoosterSlotDisplay({required this.fit, required this.index});

  @override
  Widget build(BuildContext context) {
    final item = fit.fit.body.booster[index];

    final errors = fit.output.errors
        .filter((err) => err.slot.fitItemType == FitItemType.booster && err.index == index)
        .toList();

    final trailingText =
        GlobalStorage().static.typeSlot.booster[item.itemID]!.slot.toString().text();
    final trailing = errors.isEmpty
        ? trailingText
        : Row(mainAxisSize: MainAxisSize.min, children: [
            NativeErrorTrigger(errors: errors),
            trailingText,
          ]);

    return ListTile(
      leading: StateIcon(
          state: ItemState.fromInt(item.state.state),
          foregroundImage: GlobalStorage().static.icons.getTypeIconFileImageSync(item.itemID)),
      title: Text(GlobalStorage().static.types[item.itemID]?.nameZH ?? '未知增效剂 ${item.itemID}'),
      trailing: trailing,
    );
  }
}
