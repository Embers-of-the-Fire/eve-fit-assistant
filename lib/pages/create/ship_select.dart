import 'package:eve_fit_assistant/constant/constant.dart';
import 'package:eve_fit_assistant/export/import_view.dart';
import 'package:eve_fit_assistant/export/schema.dart';
import 'package:eve_fit_assistant/main.dart';
import 'package:eve_fit_assistant/pages/create/create_dialog.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/storage/static/ships.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/item_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ShipSelectPage extends StatefulWidget {
  const ShipSelectPage({super.key});

  @override
  State<ShipSelectPage> createState() => _ShipSelectPageState();
}

class _ShipSelectPageState extends State<ShipSelectPage> {
  final FToast fToast = FToast();

  @override
  void initState() {
    fToast.init(context);
    super.initState();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('选择船只')),
        body: Column(children: [
          TypeAheadField<(int, Ship)>(
            decorationBuilder: (context, child) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: cyberTeal,
                borderRadius: BorderRadius.circular(5),
              ),
              child: child,
            ),
            onSelected: (data) => _onShipSelect(data.$1, context),
            builder: (context, controller, focusNode) => Padding(
                padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
                child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: false,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '舰船',
                    ))),
            itemBuilder: (context, data) {
              final id = data.$1;
              final ship = data.$2;
              return ListTile(
                leading: GlobalStorage().static.icons.getTypeIconSync(id),
                title: Text(ship.nameZH),
                subtitle: GlobalStorage().static.groups[ship.groupID]?.nameZH.text(),
                onLongPress: () => showTypeInfoPage(context, typeID: id),
              );
            },
            suggestionsCallback: (search) => search.isNotEmpty.then(() => GlobalStorage()
                .static
                .ships
                .tupleEntries
                .filter((data) => data.$2.published && data.$2.nameZH.contains(search))
                .toList()),
            emptyBuilder: (context) => Padding(
              padding: const EdgeInsets.all(12),
                child: Text(
              '未找到相关舰船',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
            )),
          ),
          Expanded(
              child: ItemList(
            breadcrumbPadding: const EdgeInsets.symmetric(horizontal: 20),
            breadcrumbDecoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey)),
            ),
            breadcrumbItemPadding: const EdgeInsets.symmetric(vertical: 10),
            fallbackGroupID: shipGroupID,
            baseGroup: '舰船',
            onSelect: (id) => _onShipSelect(id, context),
            onLongPress: (id) => showTypeInfoPage(context, typeID: id),
          ))
        ]),
        floatingActionButton: Container(
            margin: const EdgeInsets.only(bottom: 55),
            child: FloatingActionButton(
              onPressed: () async {
                final clip = await Clipboard.getData('text/plain');
                if (!context.mounted) return;
                final text = clip?.text;
                if (text == null) return;
                final data = FitExport.fromEncoded(text);
                if (data == null) {
                  fToast.showToast(
                      child: Container(
                    margin: const EdgeInsets.only(bottom: 20.0),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25.0),
                      color: Colors.red,
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.error_outline),
                      SizedBox(width: 12.0),
                      Text('错误的配置代码'),
                    ]),
                  ));
                } else {
                  final status = await showImportDialog(context, data);
                  if (status == false || !context.mounted) return;
                  Navigator.pop(context);
                  final fit = await GlobalStorage().ship.importFit(data);
                  if (!context.mounted) return;
                  await intoFitPage(context, fit.brief.id);
                }
              },
              shape: const CircleBorder(),
              child: const Icon(Icons.file_download_outlined),
            )),
      );
}

Future<void> _onShipSelect(int id, BuildContext context) async {
  final fitName = await showShipCreateDialog(context);
  if (fitName == null) return;
  if (context.mounted) Navigator.pop(context);
  final fit = await GlobalStorage().ship.createFit(fitName, id);
  if (context.mounted) {
    await intoFitPage(context, fit.brief.id);
  }
}
