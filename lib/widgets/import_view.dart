import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/dialog.dart';
import 'package:flutter/material.dart';

Future<bool> showImportDialog(
  BuildContext context, {
  required int shipID,
  required Map<int, int> types,
  required String name,
}) =>
    showDialog<bool>(
            context: context,
            builder: (context) => ImportViewDialog(shipID: shipID, types: types, name: name))
        .then((u) => u == true);

class ImportViewDialog extends StatelessWidget {
  final int shipID;
  final Map<int, int> types;
  final String name;

  const ImportViewDialog({
    super.key,
    required this.shipID,
    required this.types,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final shipName = GlobalStorage().static.types[shipID]?.nameZH ?? '未知';

    return AppDialog(
      title: '导入配置',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: GlobalStorage().static.icons.getTypeIconSync(shipID),
            title: Text('[$shipName] ${name}'),
          ),
          const Divider(height: 0, color: Colors.white54),
          Expanded(
              child: Scrollbar(
                  child: SingleChildScrollView(
                      child: Column(
                          children: types.entries.sortedByKey<num>((u) => u.key).map((entry) {
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
