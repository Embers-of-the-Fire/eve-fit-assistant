import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/widgets/market_list.dart';
import 'package:flutter/material.dart';

class MarketPage extends StatelessWidget {
  const MarketPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('市场'),
        ),
        body: MarketList(
          filter: (id) => GlobalStorage().static.types[id]?.published == true,
          onLongPress: (id) => showTypeInfoPage(context, typeID: id),
        ),
      );
}
