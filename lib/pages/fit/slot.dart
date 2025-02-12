import 'package:eve_fit_assistant/pages/fit/add_item_dialog.dart';
import 'package:eve_fit_assistant/pages/fit/fit.dart';
import 'package:eve_fit_assistant/pages/fit/item_info.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/optional.dart';
import 'package:flutter/material.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

Widget getSlotRow(
  String fitID,
  SlotItem? item, {
  required FitItemType type,
  required int index,
  required FitItemType slotType,
}) {
  if (item == null) {
    return SlotRowPlaceholder(fitID: fitID, type: type, index: index);
  }
  return SlotRow(
    fitID: fitID,
    typeID: item.itemID,
    state: item.state,
    maxState:
        GlobalStorage().static.typeSlot[slotType][item.itemID]?.maxState ??
            SlotState.passive,
    type: type,
    index: index,
    chargeID: item.chargeID,
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
  }) : slotHasCharge =
            GlobalStorage().static.typeSlot[type][typeID]?.hasCharge ?? false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fitData = ref.watch(fitRecordNotifierProvider(fitID));

    final List<SlidableAction> startAction = [];
    final List<SlidableAction> endAction = [];

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
    endAction.add(SlidableAction(
      onPressed: (_) =>
          _modifyFit(index: index, type: type, fit: fit, op: (_) => null),
      backgroundColor: Color(0xFFFE4A49),
      foregroundColor: Colors.white,
      icon: Icons.delete,
      label: '删除',
    ));
    if (slotHasCharge) {
      startAction.add(SlidableAction(
        onPressed: (_) async {
          final chargeID =
              await showAddChargeDialog(context, typeID, type: type);
          if (chargeID == null) return;
          _modifyFit(
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
      child: ListTile(
        onLongPress: () => showItemInfoPage(context),
        leading: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.all(Radius.circular(20)),
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
                backgroundColor: Colors.grey.shade200,
                foregroundImage: GlobalStorage()
                    .static
                    .icons
                    .getTypeIconFileImageSync(typeID),
              ),
            ),
          ),
        ),
        title: Text(GlobalStorage().static.typesAbbr[typeID]?.nameZH ?? '未知'),
        subtitle: chargeID != null
            ? Row(
                children: [
                  ...GlobalStorage()
                      .static
                      .icons
                      .getTypeIconSync(chargeID!, width: 18, height: 18)
                      .map((u) => [u])
                      .unwrapOr([]),
                  SizedBox(
                    width: 10,
                  ),
                  Text(
                    GlobalStorage().static.typesAbbr[chargeID!]?.nameZH ?? '未知',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              )
            : null,
        // trailing: InkWell(
        //   borderRadius: BorderRadius.all(Radius.circular(50)),
        //   onTap: () {},
        //   child: Container(
        //     padding: EdgeInsets.all(5),
        //     child: Icon(Icons.error_outline, color: Colors.red),
        //   ),
        // ),
      ),
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

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey.shade200,
        child: const Icon(Icons.add_circle_outline),
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
            GlobalStorage().static.typeSlot[type][newItemID]?.maxState ??
                SlotState.passive;
        final defaultState =
            maxState >= SlotState.active ? SlotState.active : maxState;
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
    );
  }
}

Future<void> _modifyFit({
  required int index,
  required FitItemType type,
  required FitRecordNotifier fit,
  required SlotItem? Function(SlotItem?) op,
}) {
  return fit.modify((fit) {
    final func = _getModifyFunction(fit, type);
    if (func == null) return fit;
    func(index, op);
    return fit;
  });
}

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
