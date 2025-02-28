import 'package:eve_fit_assistant/native/glue/unit.dart';
import 'package:eve_fit_assistant/storage/static/dynamic_item.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';

class DynamicAttributeTab extends StatelessWidget {
  final void Function(int, double) onChanged;
  final int mutaplasmidID;
  final int typeID;
  final Map<int, double> attributes;

  const DynamicAttributeTab({
    super.key,
    required this.onChanged,
    required this.mutaplasmidID,
    required this.typeID,
    required this.attributes,
  });

  @override
  Widget build(BuildContext context) {
    final typeAttr = GlobalStorage().fitEngine.getTypeAttr(typeID);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: DefaultTextStyle(
            style: const TextStyle(fontSize: 16),
            child: Column(
              spacing: 8,
              children: attributes.entries
                  .map((u) => _DynamicAttributeRow(
                        onChanged: (value) => onChanged(u.key, value),
                        value: typeAttr[u.key]!,
                        factor: u.value,
                        attributeID: u.key,
                        mutaplasmidID: mutaplasmidID,
                      ))
                  .toList(growable: false),
            )));
  }
}

class _DynamicAttributeRow extends StatefulWidget {
  /// factor
  final void Function(double) onChanged;
  final double value;
  final double factor;
  final int mutaplasmidID;
  final int attributeID;

  const _DynamicAttributeRow({
    required this.onChanged,
    required this.value,
    required this.factor,
    required this.mutaplasmidID,
    required this.attributeID,
  });

  @override
  State<StatefulWidget> createState() => _DynamicAttributeRowState();
}

class _DynamicAttributeRowState extends State<_DynamicAttributeRow> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late double factor;
  late final DynamicItem dyn;

  double validator() {
    final min = dyn.data.attributes[widget.attributeID]!.min;
    final max = dyn.data.attributes[widget.attributeID]!.max;

    final num = double.tryParse(_controller.text);
    if (num == null) {
      _controller.text = (widget.value * widget.factor).toStringAsFixed(2);
      return widget.value * widget.factor;
    } else if (num < widget.value * min) {
      _controller.text = (widget.value * min).toStringAsFixed(2);
      return widget.value * min;
    } else if (num > widget.value * max) {
      _controller.text = (widget.value * max).toStringAsFixed(2);
      return widget.value * max;
    }
    return num;
  }

  @override
  void initState() {
    dyn = GlobalStorage().static.dynamicItems[widget.mutaplasmidID]!;
    factor = widget.factor;
    _controller.text = (widget.value * widget.factor).toStringAsFixed(2);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() {
          factor = validator() / widget.value;
          widget.onChanged(factor);
        });
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final attr = GlobalStorage().static.attributes[widget.attributeID]!;
    final min = dyn.data.attributes[widget.attributeID]!.min;
    final max = dyn.data.attributes[widget.attributeID]!.max;
    final minValue = attr.highIsGood ? widget.value * min : widget.value * max;
    final maxValue = attr.highIsGood ? widget.value * max : widget.value * min;
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
                color: switch (factor.compareTo(1) * attr.highIsGood.asSign) {
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
        highIsGood: GlobalStorage().static.attributes[widget.attributeID]!.highIsGood,
        min: min,
        max: max,
      )
    ]);
  }
}

class _RatioBar extends StatelessWidget {
  final double value;
  final double min;
  final double max;

  final bool highIsGood;

  const _RatioBar({
    required this.value,
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
    } else if (highIsGood && factor > 0 || !highIsGood && factor < 0) {
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
