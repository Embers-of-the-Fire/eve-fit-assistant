import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        scrollDirection: Axis.vertical,
        controller: _scrollController,
        children: GlobalStorage()
            .ship
            .brief
            .entries
            .sortedByKey<Reversed<num>>((entry) => Reversed(entry.value.lastModifyTime))
            .map((entry) {
          final icon = GlobalStorage().static.icons.getTypeIconSync(entry.value.shipID);
          final typeName = GlobalStorage().static.types[entry.value.shipID]?.nameZH ?? '未知';
          return Slidable(
            startActionPane: ActionPane(extentRatio: 0.2, motion: const StretchMotion(), children: [
              SlidableAction(
                onPressed: (_) async {
                  final fit = await GlobalStorage().ship.copyFit(entry.value.id);
                  if (context.mounted) {
                    await intoFitPage(context, fit.brief.id);
                  }
                },
                icon: Icons.copy,
                label: '复制',
                backgroundColor: Colors.green,
              )
            ]),
            endActionPane: ActionPane(extentRatio: 0.2, motion: const StretchMotion(), children: [
              SlidableAction(
                onPressed: (_) =>
                    GlobalStorage().ship.deleteFit(entry.key).then((_) => setState(() {})),
                icon: Icons.delete_forever,
                label: '删除',
                backgroundColor: Colors.red,
              )
            ]),
            child: ListTile(
              leading: icon,
              title: Text('[$typeName] ${entry.value.name}'),
              subtitle: Text(
                DateTime.fromMillisecondsSinceEpoch(entry.value.lastModifyTime).toString(),
              ),
              onLongPress: () => showTypeInfoPage(context, typeID: entry.value.shipID),
              onTap: () => intoFitPage(context, entry.key).then((_) => setState(() {})),
            ),
          );
        }).toList(),
      );
}
