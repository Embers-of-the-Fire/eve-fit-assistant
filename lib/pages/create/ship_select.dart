import 'package:eve_fit_assistant/constant/constant.dart';
import 'package:eve_fit_assistant/pages/create/create_dialog.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/widgets/item_list.dart';
import 'package:flutter/material.dart';

class ShipSelectPage extends StatelessWidget {
  const ShipSelectPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('选择船只'),
        ),
        body: ItemList(
          breadcrumbPadding: const EdgeInsets.symmetric(horizontal: 20),
          breadcrumbDecoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey)),
          ),
          breadcrumbItemPadding: const EdgeInsets.symmetric(vertical: 10),
          fallbackGroupID: shipGroupID,
          baseGroup: '舰船',
          onSelect: (id) async {
            final fitName = await showShipCreateDialog(context);
            if (fitName == null) return;
            if (context.mounted) Navigator.pop(context);
            final fit = await GlobalStorage().ship.createFit(fitName, id);
            if (context.mounted) {
              await intoFitPage(context, fit.brief.id);
            }
          },
          onLongPress: (id) => showTypeInfoPage(context, typeID: id),
        ),
      );
}
