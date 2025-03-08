import 'package:eve_fit_assistant/export/schema.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/dialog.dart';
import 'package:flutter/material.dart';

Future<bool> showImportDialog(BuildContext context, FitExport fit) =>
    showDialog<bool>(context: context, builder: (context) => ImportViewDialog(fit: fit))
        .then((u) => u == true);

class ImportViewDialog extends StatelessWidget {
  final FitExport fit;

  const ImportViewDialog({super.key, required this.fit});

  @override
  Widget build(BuildContext context) {
    final shipName = GlobalStorage().static.types[fit.shipID]?.nameZH ?? '未知';

    final Map<int, int> typeMap = {};
    for (final slot in [fit.high, fit.med, fit.low, fit.rig, fit.subSystem, fit.implant]
        .flatMap((u) => u.nonNulls)
        .filter((u) => !u.isDynamic)) {
      typeMap[slot.itemID] = (typeMap[slot.itemID] ?? 0) + 1;
    }
    for (final drone in fit.drone) {
      typeMap[drone.itemID] = (typeMap[drone.itemID] ?? 0) + drone.amount;
    }
    for (final fighter in fit.fighter) {
      typeMap[fighter.itemID] = (typeMap[fighter.itemID] ?? 0) + fighter.amount;
    }
    for (final dyn in fit.dynamicItems.entries) {
      typeMap[dyn.value.outType] = (typeMap[dyn.value.outType] ?? 0) + 1;
    }

    return AppDialog(
      title: '导入配置',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: GlobalStorage().static.icons.getTypeIconSync(fit.shipID),
            title: Text('[$shipName] ${fit.name}'),
          ),
          const Divider(height: 0, color: Colors.white54),
          Expanded(
              child: Scrollbar(
                  child: SingleChildScrollView(
                      child: Column(
                          children: typeMap.entries.sortedByKey<num>((u) => u.key).map((entry) {
            final type = GlobalStorage().static.types[entry.key];
            if (type == null) {
              return ListTile(
                leading: GlobalStorage().static.icons.getTypeIconSync(entry.key) ??
                    const Icon(Icons.question_mark),
                title: Text('未知物品 ${entry.key}'),
                trailing: Text('× ${entry.value}', style: const TextStyle(fontSize: 16)),
              );
            }
            return ListTile(
              leading: GlobalStorage().static.icons.getTypeIconSync(entry.key) ??
                  const Icon(Icons.question_mark),
              title: Text(type.nameZH),
              trailing: Text('× ${entry.value}', style: const TextStyle(fontSize: 16)),
            );
          }).toList())))),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: ButtonStyle(
                shape: WidgetStateProperty.all(const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(5))))),
            child: const Text('取消')),
        TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ButtonStyle(
                shape: WidgetStateProperty.all(const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(5))))),
            child: const Text('导入'))
      ],
    );
  }
}
