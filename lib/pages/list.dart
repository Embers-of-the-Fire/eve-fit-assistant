import 'package:eve_fit_assistant/pages/fit/fit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/itertools.dart';
import 'package:eve_fit_assistant/utils/sort.dart';
import 'package:flutter/material.dart';

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 20),
      scrollDirection: Axis.vertical,
      controller: _scrollController,
      children: GlobalStorage()
          .ship
          .brief
          .entries
          .sortedByKey<Reversed<num>>(
              (entry) => Reversed(entry.value.lastModifyTime))
          .map((entry) {
        final icon =
            GlobalStorage().static.icons.getTypeIconSync(entry.value.shipID);
        final typeName =
            GlobalStorage().static.typesAbbr[entry.value.shipID]?.nameZH ??
                '未知';
        return ListTile(
          leading: icon,
          title: Text('[$typeName] ${entry.value.name}'),
          subtitle: Text(
            DateTime.fromMillisecondsSinceEpoch(entry.value.lastModifyTime)
                .toString(),
          ),
          onTap: () => intoFitPage(context, entry.key),
        );
      }).toList(),
    );
  }
}
