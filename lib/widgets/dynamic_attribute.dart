import 'dart:math' show Random;

import 'package:eve_fit_assistant/native/glue/unit.dart';
import 'package:eve_fit_assistant/pages/fit/panel/fit.dart';
import 'package:eve_fit_assistant/storage/static/attribute.dart';
import 'package:eve_fit_assistant/storage/static/dynamic_item.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DynamicAttributeTab extends ConsumerStatefulWidget {
  final String fitID;
  final int itemID;
  final int mutaplasmidID;
  final int typeID;
  final Map<int, double> attributes;

  const DynamicAttributeTab({
    super.key,
    required this.fitID,
    required this.itemID,
    required this.mutaplasmidID,
    required this.typeID,
    required this.attributes,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => DynamicAttributeTabState();
}

class DynamicAttributeTabState extends ConsumerState<DynamicAttributeTab>
    with AutomaticKeepAliveClientMixin {
  Map<int, ValueNotifier<double>> attributeNotifier = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    for (final entry in widget.attributes.entries) {
      attributeNotifier[entry.key] = ValueNotifier(entry.value);
    }
    super.initState();
  }

  void _updateAttributes(Map<int, double> attributes) {
    for (final entry in attributes.entries) {
      attributeNotifier[entry.key]!.value = entry.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final fitNotifier = ref.read(fitRecordNotifierProvider(widget.fitID).notifier);

    final typeAttr = GlobalStorage().fitEngine.getTypeAttr(widget.typeID);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: DefaultTextStyle(
            style: const TextStyle(fontSize: 16),
            child: Column(
              spacing: 8,
              children: [
                ...widget.attributes.entries.map((u) => _DynamicAttributeRow(
                      factorNotifier: attributeNotifier[u.key]!,
                      onChanged: (value) => fitNotifier.modify((record) {
                        final dynamicItem = record.body.dynamicItems[widget.itemID]!;
                        record.body.dynamicItems[widget.itemID] =
                            dynamicItem.copyWith(dynamicAttributes: {
                          ...dynamicItem.dynamicAttributes,
                          u.key: value,
                        });
                        return record;
                      }),
                      value: typeAttr[u.key]!,
                      attributeID: u.key,
                      mutaplasmidID: widget.mutaplasmidID,
                    )),
                Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 10, children: [
                  ElevatedButton(
                    onPressed: () => fitNotifier.modify((record) {
                      final dynamicItem = record.body.dynamicItems[widget.itemID]!;
                      final newAttr =
                          dynamicItem.dynamicAttributes.map((key, _) => MapEntry(key, 1.0));
                      record.body.dynamicItems[widget.itemID] =
                          dynamicItem.copyWith(dynamicAttributes: newAttr);
                      _updateAttributes(newAttr);
                      return record;
                    }),
                    style: ButtonStyle(
                        shape: WidgetStateProperty.all(const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(5))))),
                    child: const Text('重置', style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton(
                    onPressed: () => fitNotifier.modify((record) {
                      final dynamicItem = record.body.dynamicItems[widget.itemID]!;
                      final data = GlobalStorage().static.dynamicItems[dynamicItem.mutaplasmidID]!;
                      final newAttr = data.data.attributes.map((key, data) =>
                          MapEntry(key, Random().nextDoubleRange(data.min, data.max)));
                      record.body.dynamicItems[widget.itemID] =
                          dynamicItem.copyWith(dynamicAttributes: newAttr);
                      _updateAttributes(newAttr);
                      return record;
                    }),
                    style: ButtonStyle(
                        shape: WidgetStateProperty.all(const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(5))))),
                    child: const Text('随机'),
                  )
                ])
              ],
            )));
  }
}

class _DynamicAttributeRow extends StatefulWidget {
  /// factor
  final void Function(double) onChanged;
  final double value;
  final int mutaplasmidID;
  final int attributeID;

  final ValueNotifier<double> factorNotifier;

  const _DynamicAttributeRow({
    required this.onChanged,
    required this.value,
    required this.mutaplasmidID,
    required this.attributeID,
    required this.factorNotifier,
  });

  @override
  State<StatefulWidget> createState() => _DynamicAttributeRowState();
}

class _DynamicAttributeRowState extends State<_DynamicAttributeRow> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late final AttributeItem attributeItem;
  late final DynamicItem dyn;

  void _setControllerToDefault([double? def]) {
    _controller.text =
        (attributeItem.unitID?.displayNum(widget.value * (def ?? widget.factorNotifier.value)) ?? 0)
            .toStringAsFixed(2);
  }

  @override
  void initState() {
    dyn = GlobalStorage().static.dynamicItems[widget.mutaplasmidID]!;
    attributeItem = GlobalStorage().static.attributes[widget.attributeID]!;
    _setControllerToDefault();
    widget.factorNotifier.addListener(() {
      _setControllerToDefault();
    });
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() {
          widget.factorNotifier.value = _validator() / widget.value;
          widget.onChanged(widget.factorNotifier.value);
        });
      }
    });
    super.initState();
  }

  void setFactor(double value) {
    setState(() {
      widget.factorNotifier.value = value;
      _setControllerToDefault(value);
    });
  }

  double _validator() {
    final min = dyn.data.attributes[widget.attributeID]!.min;
    final max = dyn.data.attributes[widget.attributeID]!.max;

    final numRaw = double.tryParse(_controller.text);
    if (numRaw == null) {
      _setControllerToDefault();
      return widget.value * widget.factorNotifier.value;
    }
    final num =
        GlobalStorage().static.attributes[widget.attributeID]?.unitID?.fromDisplayNum(numRaw) ??
            numRaw;
    if (num < widget.value * min) {
      _setControllerToDefault(min);
      return widget.value * min;
    } else if (num > widget.value * max) {
      _setControllerToDefault(max);
      return widget.value * max;
    }
    return num;
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
      valueListenable: widget.factorNotifier,
      builder: (BuildContext context, double factor, Widget? child) {
        final attr = GlobalStorage().static.attributes[widget.attributeID]!;
        final min = dyn.data.attributes[widget.attributeID]!.min;
        final max = dyn.data.attributes[widget.attributeID]!.max;
        final minValue =
            (widget.value.isNegative != attr.highIsGood) ? widget.value * min : widget.value * max;
        final maxValue =
            (widget.value.isNegative != attr.highIsGood) ? widget.value * max : widget.value * min;
        final currentValue = widget.value * factor;

        return Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(attr.displayNameZH),
            SizedBox(
                height: 40,
                width: 100,
                child: TextField(
                  focusNode: _focusNode,
                  controller: _controller,
                  decoration: const InputDecoration(hintText: '属性值'),
                  textAlign: TextAlign.end,
                )),
          ]),
          const SizedBox(height: 5),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(attr.unitID.map((u) => u.format(minValue)).unwrapOr(minValue.toStringAsFixed(2)),
                style: const TextStyle(color: Colors.red)),
            Text(
                attr.unitID
                    .map((u) => u.format(currentValue))
                    .unwrapOr(currentValue.toStringAsFixed(2)),
                style: TextStyle(
                    color: switch (
                        currentValue.sign * factor.compareTo(1) * attr.highIsGood.asSign) {
                  < 0 => Colors.red,
                  > 0 => Colors.green,
                  _ => Colors.white,
                })),
            Text(attr.unitID.map((u) => u.format(maxValue)).unwrapOr(maxValue.toStringAsFixed(2)),
                style: const TextStyle(color: Colors.green)),
          ]),
          const SizedBox(height: 5),
          _RatioBar(
            value: factor,
            isPositive: !currentValue.isNegative,
            highIsGood: GlobalStorage().static.attributes[widget.attributeID]!.highIsGood,
            min: min,
            max: max,
          )
        ]);
      });
}

class _RatioBar extends StatelessWidget {
  final double value;
  final double min;
  final double max;

  final bool isPositive;
  final bool highIsGood;

  const _RatioBar({
    required this.value,
    required this.isPositive,
    required this.highIsGood,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final factor = value == 1
        ? 0
        : value > 1
            ? (value - 1) / (max - 1)
            : (value - 1) / (1 - min);

    const radius = Radius.circular(5);

    final List<Flexible> children = [];
    if (factor == 0) {
      children.add(Flexible(
          flex: 100,
          child: Container(
              decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white)),
          ))));
      children.add(Flexible(
          flex: 100,
          child: Container(
              decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.white)),
          ))));
    } else if ((isPositive == highIsGood) && factor > 0 || isPositive != highIsGood && factor < 0) {
      children.add(Flexible(
          flex: 100,
          child: Container(
            decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Colors.white)),
                borderRadius: BorderRadius.only(topLeft: radius, bottomLeft: radius)),
          )));
      children.add(Flexible(
          flex: (factor.abs() * 100).toInt(),
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(topRight: radius, bottomRight: radius),
              border: Border(left: BorderSide(color: Colors.white)),
              color: Colors.green,
            ),
          )));
      children.add(Flexible(
          flex: ((1 - factor.abs()) * 100).toInt(),
          child: Container(
              decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(topRight: radius, bottomRight: radius),
          ))));
    } else {
      children.add(Flexible(
          flex: ((1 - factor.abs()) * 100).toInt(),
          child: Container(
              decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(topLeft: radius, bottomLeft: radius),
          ))));
      children.add(Flexible(
          flex: (factor.abs() * 100).toInt(),
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: radius, bottomLeft: radius),
              border: Border(right: BorderSide(color: Colors.white)),
              color: Colors.red,
            ),
          )));
      children.add(Flexible(
          flex: 100,
          child: Container(
              decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Colors.white)),
            borderRadius: BorderRadius.only(topRight: radius, bottomRight: radius),
          ))));
    }

    return Container(
      width: double.infinity,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
    );
  }
}
