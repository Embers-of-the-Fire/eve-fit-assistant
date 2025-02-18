import 'package:eve_fit_assistant/native/glue/unit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';

class AttributeTab extends StatefulWidget {
  final int typeID;
  final Map<int, double> attr;

  const AttributeTab({super.key, required this.typeID, required this.attr});

  @override
  State<AttributeTab> createState() => _AttributeTabState();
}

class _AttributeTabState extends State<AttributeTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final original = GlobalStorage().fitEngine.getTypeAttr(widget.typeID);
    final out = widget.attr.entries
        .filterMap((e) => GlobalStorage().static.attributes[e.key].map((a) => (e, a)))
        .filter((e) => e.$2.published && e.$2.displayNameZH.isNotEmpty)
        .groupBy<num>((e) => e.$2.categoryID ?? -1)
        .sorted()
        .flatMap((entry) => entry.value.sortedByKey<num>((v) => v.$1.key))
        .map((entry) {
      final id = entry.$1.key;
      final value = entry.$1.value;
      final data = entry.$2;
      final icon = data.iconID
          .andThen<Widget>((u) => GlobalStorage().static.icons.getIconSync(u, width: 24))
          .unwrapOr(const Icon(Icons.square_outlined, color: Colors.transparent));
      final title = data.displayNameZH;
      final valueString = data.unitID?.format(value) ?? value.toStringAsFixed(2);
      final originalValue = original[id];
      final color = originalValue.map((orig) => data.highIsGood
          ? (orig > value ? Colors.red : (orig < value ? Colors.green : null))
          : (orig > value ? Colors.green : (orig < value ? Colors.red : null)));
      return TableRow(children: [
        icon,
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
                Text(valueString,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: color,
                    )),
              ],
            ))
      ]);
    });

    return SingleChildScrollView(
      controller: _controller,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(24),
            1: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: out.toList(),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
