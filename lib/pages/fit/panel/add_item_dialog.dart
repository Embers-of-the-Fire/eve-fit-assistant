import 'dart:developer';

import 'package:eve_fit_assistant/constant/eve/groups.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/static/ship_subsystems.dart';
import 'package:eve_fit_assistant/storage/static/types.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/item_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class _DialogMetadata {
  final String title;
  final String baseName;
  final int fallbackGroupID;
  final bool Function(int) predicate;

  _DialogMetadata({
    required this.title,
    required this.baseName,
    required this.fallbackGroupID,
    required this.predicate,
  });
}

Future<int?> showAddItemDialog(
  BuildContext context, {
  required FitItemType type,
  int? slotIndex,
}) async {
  final dialogMetadataMap = {
    FitItemType.high: _DialogMetadata(
      title: '添加高槽物品',
      baseName: '装备',
      fallbackGroupID: 9,
      predicate: (int itemID) => GlobalStorage().static.typeSlot.high[itemID] != null,
    ),
    FitItemType.med: _DialogMetadata(
      title: '添加中槽物品',
      baseName: '装备',
      fallbackGroupID: 9,
      predicate: (int itemID) => GlobalStorage().static.typeSlot.med[itemID] != null,
    ),
    FitItemType.low: _DialogMetadata(
      title: '添加低槽物品',
      baseName: '装备',
      fallbackGroupID: 9,
      predicate: (int itemID) => GlobalStorage().static.typeSlot.low[itemID] != null,
    ),
    FitItemType.rig: _DialogMetadata(
      title: '添加改装件',
      baseName: '改装件',
      fallbackGroupID: 1111,
      predicate: (int itemID) => GlobalStorage().static.typeSlot.rig[itemID] != null,
    ),
    FitItemType.subsystem: _DialogMetadata(
      title: '添加子系统',
      baseName: '子系统',
      fallbackGroupID: 1112,
      predicate: (int itemID) => GlobalStorage().static.typeSlot.subsystem[itemID] != null,
    ),
    FitItemType.drone: _DialogMetadata(
      title: '添加无人机',
      baseName: '无人机',
      fallbackGroupID: 157,
      predicate: (int itemID) => true,
    ),
    FitItemType.implant: _DialogMetadata(
      title: '添加植入体',
      baseName: '植入体',
      fallbackGroupID: 27,
      predicate: (int itemID) =>
          (GlobalStorage().static.typeSlot.implant[itemID]?.slot ?? -1) == (slotIndex ?? -2),
    ),
  };

  return await _showAddItemDialogImpl(context, dialogMetadataMap[type]!);
}

Future<int?> showAddSubsystemDialog(
  BuildContext context, {
  required int shipID,
  required SubsystemType type,
}) async {
  final subShip = GlobalStorage().static.subsystems.ships[shipID];
  final marketGroupID = subShip?.getMarketID(type) ?? 1112;
  final groupName = GlobalStorage().static.marketGroups[marketGroupID]?.nameZH ?? '子系统';
  final metadata = _DialogMetadata(
    title: '添加子系统',
    baseName: groupName,
    fallbackGroupID: marketGroupID,
    predicate: (int itemID) {
      final ship = GlobalStorage().static.subsystems.ships[shipID];
      if (ship == null) return false;
      final subsystem = ship[type];
      return subsystem.contains(itemID);
    },
  );

  return await _showAddItemDialogImpl(context, metadata);
}

Future<int?> showAddChargeDialog(
  BuildContext context,
  int itemID, {
  required FitItemType type,
}) async {
  final itemMetadata = GlobalStorage().static.typeSlot[type][itemID];
  final chargeGroups = itemMetadata?.chargeGroups ?? [];
  log('$chargeGroups', name: 'showAddChargeDialog');
  final metadata = _DialogMetadata(
      title: '添加弹药',
      baseName: '弹药',
      fallbackGroupID: 11,
      predicate: (int chargeID) {
        final chargeGroupID = GlobalStorage().static.types[chargeID]?.groupID;
        if (chargeGroupID == null) return true;
        return chargeGroups.contains(chargeGroupID);
      });

  return await _showAddItemDialogImpl(context, metadata);
}

Future<int?> showAddDroneDialog(
  BuildContext context,
) async {
  final metadata = _DialogMetadata(
    title: '添加无人机',
    baseName: '无人机',
    fallbackGroupID: 157,
    predicate: (item) {
      final groupID = GlobalStorage().static.types[item]?.groupID;

      return groupID == null || !fighterGroupIDs.contains(groupID);
    },
  );

  return await _showAddItemDialogImpl(context, metadata);
}

Future<int?> showAddFighterDialog(
  BuildContext context,
) async {
  final metadata = _DialogMetadata(
    title: '添加舰载机',
    baseName: '舰载机',
    fallbackGroupID: 2236,
    predicate: (item) {
      final groupID = GlobalStorage().static.types[item]?.groupID;

      return groupID == null || fighterGroupIDs.contains(groupID);
    },
  );

  return await _showAddItemDialogImpl(context, metadata);
}

Future<int?> _showAddItemDialogImpl(BuildContext context, _DialogMetadata metadata) async {
  final out = await showDialog<int>(
      context: context,
      builder: (context) => Container(
            padding: const EdgeInsets.symmetric(vertical: 120),
            child: AlertDialog(
              title: Text(metadata.title),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              content: _AddItemDialog(
                fallbackGroupID: metadata.fallbackGroupID,
                baseBreadcrumbName: metadata.baseName,
                filter: metadata.predicate,
                onSelect: (id) => Navigator.pop(context, id),
              ),
            ),
          ));

  return out;
}

class _AddItemDialog extends StatelessWidget {
  final int? fallbackGroupID;
  final String? baseBreadcrumbName;
  final bool Function(int)? filter;
  final void Function(int)? onSelect;

  const _AddItemDialog({
    this.fallbackGroupID,
    this.baseBreadcrumbName,
    this.filter,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        TypeAheadField<(int, TypeItem)>(
          onSelected: (data) => onSelect?.call(data.$1),
          builder: (context, controller, focusNode) => Padding(
              padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
              child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '装备',
                  ))),
          itemBuilder: (context, data) {
            final id = data.$1;
            final item = data.$2;
            return ListTile(
              leading: GlobalStorage().static.icons.getTypeIconSync(id),
              title: Text(item.nameZH),
              subtitle: GlobalStorage().static.groups[item.groupID]?.nameZH.text(),
              onLongPress: () => showTypeInfoPage(context, typeID: id),
            );
          },
          suggestionsCallback: (search) => search.isNotEmpty.then(() => GlobalStorage()
              .static
              .types
              .tupleEntries
              .filter((data) =>
                  data.$2.published &&
                  data.$2.nameZH.contains(search) &&
                  filter.map((u) => u(data.$1)).unwrapOr(true))
              .toList()),
          emptyBuilder: (context) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '未找到相关装备',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(
            child: ItemList(
          breadcrumbPadding: const EdgeInsets.symmetric(horizontal: 20),
          breadcrumbDecoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey)),
          ),
          fallbackGroupID: fallbackGroupID,
          baseGroup: baseBreadcrumbName,
          breadcrumbItemPadding: const EdgeInsets.symmetric(vertical: 10),
          filter: filter,
          onSelect: onSelect,
          onLongPress: (id) => showTypeInfoPage(context, typeID: id),
        ))
      ]);
}
