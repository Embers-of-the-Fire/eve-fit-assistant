import 'dart:developer';

import 'package:eve_fit_assistant/export/schema.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final _scrollController = ScrollController();
  final FToast fToast = FToast();

  @override
  void initState() {
    super.initState();
    fToast.init(context);
  }

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
            startActionPane: ActionPane(extentRatio: 0.3, motion: const StretchMotion(), children: [
              SlidableAction(
                onPressed: (_) async {
                  final fit = await GlobalStorage().ship.copyFit(entry.value.id);
                  if (context.mounted) {
                    await intoFitPage(context, fit.brief.id);
                  }
                },
                padding: EdgeInsets.zero,
                icon: Icons.copy,
                label: '复制',
                backgroundColor: Colors.green,
              ),
              SlidableAction(
                onPressed: (_) async {
                  final fit = await GlobalStorage().ship.readFit(entry.value.id);
                  final export = FitExport.fromRecord(fit);
                  final text = export.encoded;
                  log(text, name: 'exportToBase64');
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  fToast.showToast(
                      child: Container(
                    margin: const EdgeInsets.only(bottom: 20.0),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25.0),
                      color: Theme.of(context).colorScheme.inversePrimary,
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check),
                      SizedBox(width: 12.0),
                      Text('已复制到剪贴板'),
                    ]),
                  ));
                },
                padding: EdgeInsets.zero,
                icon: Icons.share,
                label: '分享',
                backgroundColor: Colors.white,
              )
            ]),
            endActionPane: ActionPane(extentRatio: 0.15, motion: const StretchMotion(), children: [
              SlidableAction(
                onPressed: (_) =>
                    GlobalStorage().ship.deleteFit(entry.key).then((_) => setState(() {})),
                padding: EdgeInsets.zero,
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
