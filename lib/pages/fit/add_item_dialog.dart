part of 'fit.dart';

enum FitItemType {
  high,
  med,
  low,
  rig,
  subsystem,
  drone,
  implant,
}

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
      predicate: (int itemID) =>
          GlobalStorage().static.typeSlot.high[itemID] != null,
    ),
    FitItemType.med: _DialogMetadata(
      title: '添加中槽物品',
      baseName: '装备',
      fallbackGroupID: 9,
      predicate: (int itemID) =>
          GlobalStorage().static.typeSlot.med[itemID] != null,
    ),
    FitItemType.low: _DialogMetadata(
      title: '添加低槽物品',
      baseName: '装备',
      fallbackGroupID: 9,
      predicate: (int itemID) =>
          GlobalStorage().static.typeSlot.low[itemID] != null,
    ),
    FitItemType.rig: _DialogMetadata(
      title: '添加改装件',
      baseName: '改装件',
      fallbackGroupID: 1111,
      predicate: (int itemID) =>
          GlobalStorage().static.typeSlot.rig[itemID] != null,
    ),
    FitItemType.subsystem: _DialogMetadata(
      title: '添加子系统',
      baseName: '子系统',
      fallbackGroupID: 1112,
      predicate: (int itemID) =>
          GlobalStorage().static.typeSlot.subsystem[itemID] != null,
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
          (GlobalStorage().static.typeSlot.implant[itemID]?.slot ?? -1) ==
          (slotIndex ?? -2),
    ),
  };

  return await _showAddItemDialogImpl(context, dialogMetadataMap[type]!);
}

Future<int?> showAddChargeDialog(
  BuildContext context,
  int itemID, {
  required FitItemType type,
}) async {
  final itemMetadata = GlobalStorage().static.typeSlot[type][itemID];
  final chargeGroups = itemMetadata?.chargeGroups ?? [];
  final metadata = _DialogMetadata(
      title: '添加弹药',
      baseName: '弹药',
      fallbackGroupID: 11,
      predicate: (int chargeID) {
        final chargeGroupID =
            GlobalStorage().static.typesAbbr[chargeID]?.groupID;
        if (chargeGroupID == null) return true;
        return chargeGroups.contains(chargeGroupID);
      });

  return await _showAddItemDialogImpl(context, metadata);
}

Future<int?> _showAddItemDialogImpl(
    BuildContext context, _DialogMetadata metadata) async {
  final out = await showDialog<int>(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 120),
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
        );
      });

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
  Widget build(BuildContext context) {
    return ItemList(
      breadcrumbPadding: EdgeInsets.symmetric(horizontal: 20),
      breadcrumbDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      fallbackGroupID: fallbackGroupID,
      baseGroup: baseBreadcrumbName,
      breadcrumbItemPadding: EdgeInsets.symmetric(vertical: 10),
      filter: filter,
      onSelect: onSelect,
    );
  }
}
