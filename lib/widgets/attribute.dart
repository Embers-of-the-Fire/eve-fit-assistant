import 'package:eve_fit_assistant/native/glue/unit.dart';
import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';

class AttributeTab extends StatefulWidget {
  final int typeID;
  final Map<int, double>? attr;

  const AttributeTab({super.key, required this.typeID, required this.attr});

  @override
  State<AttributeTab> createState() => _AttributeTabState();
}

class _AttributeTabState extends State<AttributeTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ListView(
      controller: _controller,
      children: (widget.attr == null ? renderNoAttr(context) : renderAttr(context, widget.attr!))
          .toList(),
    );
  }

  Iterable<ListTile> renderNoAttr(context) {
    final debug = Preference().debug == Debug.enable;
    final original = GlobalStorage().fitEngine.getTypeAttr(widget.typeID);
    final out = original.entries
        .filterMap((e) => GlobalStorage().static.attributes[e.key].map((a) => (e, a)))
        .filter((e) => debug || (e.$2.published && e.$2.displayNameZH.isNotEmpty))
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
      final valueString = data.unitID?.format(value) ?? value.toStringAsMaxDecimals(2);
      final (titleW, subtitleW) = title.isEmpty
          ? (SelectableText(':: ${data.name}[$id]'), null)
          : (
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
              debug.then(() => SelectableText('${data.name}[$id]'))
            );
      return ListTile(
        minVerticalPadding: 8,
        minTileHeight: 0,
        leading: icon,
        title: titleW,
        subtitle: subtitleW,
        trailing:
            Text(valueString, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
      );
    });

    return out;
  }

  Iterable<ListTile> renderAttr(BuildContext context, Map<int, double> attr) {
    final debug = Preference().debug == Debug.enable;
    final original = GlobalStorage().fitEngine.getTypeAttr(widget.typeID);
    final out = attr.entries
        .filterMap((e) => GlobalStorage().static.attributes[e.key].map((a) => (e, a)))
        .filter((e) => debug || (e.$2.published && e.$2.displayNameZH.isNotEmpty))
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
      final valueString = data.unitID?.format(value) ?? value.toStringAsMaxDecimals(2);
      final originalValue = original[id];
      final color = originalValue.map((orig) => (value.isNegative != data.highIsGood)
          ? (orig > value ? Colors.red : (orig < value ? Colors.green : null))
          : (orig > value ? Colors.green : (orig < value ? Colors.red : null)));
      final (titleW, subtitleW) = title.isEmpty
          ? (SelectableText(':: ${data.name}[$id]'), null)
          : (
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
              debug.then(() => SelectableText('${data.name}[$id]'))
            );
      return ListTile(
        minVerticalPadding: 8,
        minTileHeight: 0,
        leading: icon,
        title: titleW,
        subtitle: subtitleW,
        trailing: Text(valueString,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: color)),
      );
    });

    return out;
  }

  @override
  bool get wantKeepAlive => true;
}
