import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";

class DropdownListTile<T> extends StatefulWidget {
  const DropdownListTile({
    required this.initialValue,
    required this.title,
    required this.items,
    super.key,
    this.icon,
    this.onValueChange,
    this.subtitle,
  });
  final T initialValue;
  final void Function(T)? onValueChange;

  final IconData? icon;
  final String title;
  final String? subtitle;

  final List<DropdownMenuItem<T>> items;

  @override
  State<DropdownListTile<T>> createState() => _DropdownListTileState();
}

class _DropdownListTileState<T> extends State<DropdownListTile<T>> {
  late T value = widget.initialValue;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: widget.icon.map(Icon.new),
    title: Text(widget.title),
    subtitle: widget.subtitle.map(Text.new),
    trailing: Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButton(
        value: value,
        items: widget.items,
        onChanged: (value) => setState(() {
          if (value != null) {
            this.value = value;
            widget.onValueChange?.call(value);
          }
        }),
      ),
    ),
  );
}
