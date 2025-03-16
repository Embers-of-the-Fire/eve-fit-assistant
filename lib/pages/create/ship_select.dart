import 'package:eve_fit_assistant/constant/constant.dart';
import 'package:eve_fit_assistant/export/schema.dart';
import 'package:eve_fit_assistant/pages/create/create_dialog.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/storage/static/ships.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/theme/color.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/import_view.dart';
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
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: cyberTeal,
                borderRadius: BorderRadius.circular(5),
              ),
              child: child,
            ),
            onSelected: (data) => _onShipSelect(data.$1, context),
            builder: (context, controller, focusNode) => Padding(
                padding: const EdgeInsets.only(top: 10, left: 8, right: 8),
                child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: false,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                          borderRadius: const BorderRadius.all(Radius.circular(2))),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                          borderRadius: const BorderRadius.all(Radius.circular(2))),
                      border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(2))),
                      labelText: '舰船',
                    ))),
            itemBuilder: (context, data) {
              final id = data.$1;
              final ship = data.$2;
              return ListTile(
                leading: GlobalStorage().static.icons.getTypeIconSync(id),
                title: Text(ship.nameZH),
                subtitle: GlobalStorage().static.groups[ship.groupID]?.nameZH.text(),
                onTap: () => _onShipSelect(id, context),
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
                child: Text('未找到相关舰船',
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
          ),
          Expanded(
              child: ItemList(
            breadcrumbPadding: const EdgeInsets.symmetric(horizontal: 20),
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
                  await _intoImportDialog(context, data);
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

Future<void> _intoImportDialog(BuildContext context, FitExport fit) async {
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
  final status =
      await showImportDialog(context, shipID: fit.shipID, types: typeMap, name: fit.name);
  if (status == false || !context.mounted) return;
  Navigator.pop(context);
  final output = await GlobalStorage().ship.importFit(fit);
  if (!context.mounted) return;
  await intoFitPage(context, output.brief.id);
}
