import 'package:eve_fit_assistant/utils/fp.dart';
import 'package:flutter/material.dart';

class DropdownListTile<T> extends StatefulWidget {
  final T initialValue;
  final void Function(T)? onValueChange;

  final IconData? icon;
  final String title;
  final String? subtitle;

  final List<DropdownMenuItem<T>> items;

  const DropdownListTile({
    super.key,
    this.icon,
    required this.initialValue,
    this.onValueChange,
    required this.title,
    this.subtitle,
    required this.items,
  });

  @override
  State<DropdownListTile<T>> createState() => _DropdownListTileState();
}

class _DropdownListTileState<T> extends State<DropdownListTile<T>> {
  late T value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: widget.icon.map((f) => Icon(f)),
      title: Text(widget.title),
      subtitle: widget.subtitle.map((t) => Text(t)),
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
}
