import 'dart:developer';

import 'package:eve_fit_assistant/export/schema.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/web/esi/storage/esi.dart';
import 'package:eve_fit_assistant/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'list.g.dart';

@riverpod
Future<int?> exportFitToGame(Ref ref, String fitID) async => await GlobalStorage()
    .ship
    .readFit(fitID)
    .then((fit) async => await ref.watch(esiDataStorageProvider.notifier).exportFittings(fit));

class ListPage extends ConsumerStatefulWidget {
  const ListPage({super.key});

  @override
  ConsumerState<ListPage> createState() => _ListPageState();
}

class _ListPageState extends ConsumerState<ListPage> {
  final FToast fToast = FToast();

  @override
  void initState() {
    super.initState();
    fToast.init(context);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: Scrollbar(
          child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        children: GlobalStorage()
            .ship
            .brief
            .entries
            .sortedByKey<Reversed<num>>((entry) => Reversed(entry.value.lastModifyTime))
            .map((entry) {
          final icon = GlobalStorage().static.icons.getTypeIconSync(entry.value.shipID);
          final typeName = GlobalStorage().static.types[entry.value.shipID]?.nameZH ?? '未知';
          return Slidable(
            startActionPane:
                ActionPane(extentRatio: 0.45, motion: const StretchMotion(), children: [
              SlidableAction(
                onPressed: (_) async {
                  final fit = await GlobalStorage().ship.copyFit(entry.value.id);
                  if (context.mounted) {
                    await intoFitPage(context, fit.brief.id);
                  }
                },
                padding: EdgeInsets.zero,
                icon: Icons.copy,
                label: '导出',
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
              ),
              SlidableAction(
                onPressed: (_) => showConfirmDialog(context,
                    title: '导出配置',
                    description: '这将会将配置导出到游戏中。',
                    warning: '受 ESI 系统限制，装配数值的查询每 300 秒刷新一次。因此导出行为不会立刻生效。',
                    onConfirm: () => ref.read(exportFitToGameProvider(entry.key))),
                padding: EdgeInsets.zero,
                icon: Icons.output_outlined,
                label: '导出',
                backgroundColor: Colors.greenAccent,
              ),
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
      )));
}
