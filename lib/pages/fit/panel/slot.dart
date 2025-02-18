import 'package:eve_fit_assistant/assets/icon.dart';
import 'package:eve_fit_assistant/constant/eve/attribute.dart';
import 'package:eve_fit_assistant/native/glue/native_slot.dart';
import 'package:eve_fit_assistant/native/port/api/proxy.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/fit/panel/add_item_dialog.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/pages/fit/panel/native_error.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/static/ship_subsystems.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

part 'slot_subsystem.dart';
part 'slot_tactical_mode.dart';

extension ModulesProxyExt on ShipProxy {
  List<ItemProxy> getSlots(FitItemType type) => switch (type) {
        FitItemType.high => modules.high,
        FitItemType.med => modules.medium,
        FitItemType.low => modules.low,
        FitItemType.rig => modules.rig,
        FitItemType.subsystem => modules.subsystem,
        FitItemType.implant => implants,
        _ => [],
      };
}

Widget getSlotRow(
  String fitID,
  SlotItem? item, {
  required FitItemType type,
  required int index,
}) {
  if (type == FitItemType.subsystem) {
    final subType = SubsystemType.values[index];
    if (item == null) {
      return SubsystemSlotRowPlaceholder(fitID: fitID, type: subType);
    } else {
      return SubsystemSlotRow(fitID: fitID, typeID: item.itemID, type: subType);
    }
  }

  if (item == null) {
    return SlotRowPlaceholder(fitID: fitID, type: type, index: index);
  }
  return SlotRow(
    fitID: fitID,
    typeID: item.itemID,
    state: item.state,
    maxState: GlobalStorage().static.typeSlot[type][item.itemID]?.maxState ?? SlotState.passive,
    type: type,
    index: index,
    chargeID: item.chargeID,
    enableCopy: switch (type) {
      FitItemType.high || FitItemType.med || FitItemType.low || FitItemType.rig => true,
      _ => false,
    },
  );
}

class SlotRow extends ConsumerWidget {
  final String fitID;
  final int typeID;
  final SlotState state;
  final SlotState maxState;
  final FitItemType type;
  final int index;
  final int? chargeID;
  final bool enableCopy;

  /// Whether the slot can be "charged".
  final bool slotHasCharge;

  SlotRow({
    super.key,
    required this.fitID,
    required this.typeID,
    required this.state,
    required this.maxState,
    required this.type,
    required this.index,
    required this.chargeID,
    required this.enableCopy,
  }) : slotHasCharge = GlobalStorage().static.typeSlot[type][typeID]?.hasCharge ?? false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fitData = ref.watch(fitRecordNotifierProvider(fitID));

    final List<SlidableAction> startAction = [];
    final List<SlidableAction> endAction = [];

    if (enableCopy) {
      startAction.add(SlidableAction(
        onPressed: (_) {
          final fitSlot = fitData.fit.body.getSlots(type);
          final index = fitSlot.indexWhere((el) => el == null);
          if (index == -1) return;
          _modifyFit(
            index: index,
            type: type,
            fit: fit,
            op: (_) => SlotItem(
              itemID: typeID,
              chargeID: chargeID,
              state: state,
            ),
          );
        },
        autoClose: false,
        icon: Icons.copy,
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black,
        label: '复制',
      ));
    }
    endAction.add(SlidableAction(
      onPressed: (_) => _modifyFit(index: index, type: type, fit: fit, op: (_) => null),
      backgroundColor: const Color(0xFFFE4A49),
      foregroundColor: Colors.white,
      icon: Icons.delete,
      label: '删除',
    ));
    if (slotHasCharge) {
      startAction.add(SlidableAction(
        onPressed: (_) async {
          final chargeID = await showAddChargeDialog(context, typeID, type: type);
          if (chargeID == null) return;
          await _modifyFit(
            index: index,
            type: type,
            fit: fit,
            op: (item) => item?.copyWith(chargeID: chargeID),
          );
        },
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: Icons.battery_charging_full,
        label: '弹药',
      ));
      if (chargeID != null) {
        endAction.add(SlidableAction(
          onPressed: (_) => _modifyFit(
            index: index,
            type: type,
            fit: fit,
            op: (item) => item?.copyWith(chargeID: null),
          ),
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
          icon: Icons.cancel_outlined,
          label: '弹药',
        ));
      }
    }

    return Slidable(
      startActionPane: startAction.isEmpty
          ? null
          : ActionPane(
              extentRatio: 0.2 * startAction.length,
              motion: const StretchMotion(),
              children: startAction,
            ),
      endActionPane: endAction.isEmpty
          ? null
          : ActionPane(
              extentRatio: 0.2 * endAction.length,
              motion: const StretchMotion(),
              children: endAction,
            ),
      child: _SlotRowDisplay(
          fitID: fitID,
          index: index,
          typeID: typeID,
          chargeID: chargeID,
          type: type,
          state: state,
          maxState: maxState),
    );
  }
}

class _SlotRowDisplay extends ConsumerWidget {
  final String fitID;
  final int index;
  final int typeID;
  final int? chargeID;
  final FitItemType type;
  final SlotState state;
  final SlotState maxState;

  const _SlotRowDisplay({
    required this.fitID,
    required this.index,
    required this.typeID,
    required this.chargeID,
    required this.type,
    required this.state,
    required this.maxState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fitData = ref.watch(fitRecordNotifierProvider(fitID));

    final List<ItemProxy> slots = fitData.output.ship.getSlots(type);
    final ItemProxy? item = slots.find((item) => item.index == index);

    final List<List<Widget>> subtitleGroup = [];

    {
      // charge
      final List<Widget> row = [];

      if (chargeID != null) {
        final icon = GlobalStorage().static.icons.getTypeIconSync(chargeID!, width: 18, height: 18);
        if (icon != null) {
          row.add(icon);
          row.add(const SizedBox(width: 10));
        }
        final chargeName = GlobalStorage().static.types[chargeID!]?.nameZH ?? '未知';
        row.add(Text(chargeName, style: const TextStyle(fontSize: 14)));
      }

      if (row.isNotEmpty) {
        subtitleGroup.add(row);
      }
    }

    {
      // fire range
      final List<Widget> row = [];
      if (item != null) {
        final range = item.attributes[maxRange];
        if (range != null && range > 0) {
          // turret
          row.add(const Image(image: targetRangeImage, width: 18, height: 18));
          row.add(const SizedBox(width: 10));
          String text = '${(range / 1000).toStringAsFixed(1)} km';

          final extraRange = item.attributes[falloff];
          if (extraRange != null && extraRange > 0) {
            text += ' + ${(extraRange / 1000).toStringAsFixed(1)} km';
          }

          final extraEffectRange = item.attributes[falloffEffectiveness];
          if (extraEffectRange != null && extraEffectRange > 0) {
            text += ' + ${(extraEffectRange / 1000).toStringAsFixed(1)} km';
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
            row.add(const SizedBox(width: 10));
            row.add(Text('${range.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 14)));
          }
        } else {
          final effectRange = item.attributes[empFieldRange];
          if (effectRange != null) {
            row.add(const Image(image: targetRangeImage, width: 18, height: 18));
            row.add(const SizedBox(width: 10));
            row.add(Text(
              '${(effectRange / 1000).toStringAsFixed(1)} km',
              style: const TextStyle(fontSize: 14),
            ));
          }
        }
      }

      if (row.isNotEmpty) {
        subtitleGroup.add(row);
      }
    }

    final errors = fitData.output.errors
        .filter((err) => err.slot.fitItemType == type && err.index == index)
        .toList();

    return ListTile(
      onLongPress: item.map((i) => () => showItemInfoPage(context, typeID: typeID, item: i)),
      leading: Ink(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          onTap: () async {
            final newState = state.nextState(maxState: maxState);
            await _modifyFit(
              index: index,
              type: type,
              fit: fit,
              op: (item) => item?.copyWith(state: newState),
            );
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: getSlotColor(state),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade800,
              foregroundImage: GlobalStorage().static.icons.getTypeIconFileImageSync(typeID),
            ),
          ),
        ),
      ),
      title: Text(GlobalStorage().static.types[typeID]?.nameZH ?? '未知'),
      subtitle: subtitleGroup.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: subtitleGroup.map((group) => Row(children: group)).toList(),
            ),
      trailing: errors.isNotEmpty ? NativeErrorTrigger(errors: errors) : null,
    );
  }
}

class SlotRowPlaceholder extends ConsumerWidget {
  final String fitID;
  final FitItemType type;
  final int index;

  const SlotRowPlaceholder({
    super.key,
    required this.fitID,
    required this.type,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fitData = ref.watch(fitRecordNotifierProvider(fitID));

    final errors = fitData.output.errors
        .filter((err) => err.slot.fitItemType == type && err.index == index)
        .toList();

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        child: switch (type) {
          FitItemType.high => const Image(image: highPlaceholderImage, width: 30, height: 30),
          FitItemType.med => const Image(image: mediumPlaceholderImage, width: 30, height: 30),
          FitItemType.low => const Image(image: lowPlaceholderImage, width: 30, height: 30),
          FitItemType.rig => const Image(image: rigPlaceholderImage, width: 30, height: 30),
          _ => const Icon(Icons.add_circle_outline)
        },
      ),
      title: const Text('无装备'),
      onTap: () async {
        final newItemID = await showAddItemDialog(
          context,
          type: type,
          slotIndex: index,
        );
        if (newItemID == null) return;
        final maxState =
            GlobalStorage().static.typeSlot[type][newItemID]?.maxState ?? SlotState.passive;
        final defaultState = maxState >= SlotState.active ? SlotState.active : maxState;
        await _modifyFit(
          index: index,
          type: type,
          fit: fit,
          op: (_) => SlotItem(
            itemID: newItemID,
            chargeID: null,
            state: defaultState,
          ),
        );
      },
      trailing: errors.isNotEmpty ? NativeErrorTrigger(errors: errors) : null,
    );
  }
}

Future<void> _modifyFit({
  required int index,
  required FitItemType type,
  required FitRecordNotifier fit,
  required SlotItem? Function(SlotItem?) op,
}) =>
    fit.modify((fit) {
      final func = _getModifyFunction(fit, type);
      if (func == null) return fit;
      func(index, op);
      return fit;
    });

void Function(int, SlotItem? Function(SlotItem?))? _getModifyFunction(
  FitRecord record,
  FitItemType type,
) {
  final mapping = {
    FitItemType.high: record.modifyHigh,
    FitItemType.med: record.modifyMed,
    FitItemType.low: record.modifyLow,
    FitItemType.rig: record.modifyRig,
    FitItemType.implant: record.modifyImplant,
  };
  return mapping[type];
}

Color getSlotColor(SlotState state) {
  switch (state) {
    case SlotState.active:
      return Colors.green.shade400;
    case SlotState.online:
      return Colors.grey.shade400;
    case SlotState.overload:
      return Colors.red.shade400;
    case SlotState.passive:
      return Colors.grey.shade800;
  }
}
