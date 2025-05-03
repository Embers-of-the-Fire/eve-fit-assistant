import 'package:eve_fit_assistant/theme/color.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';

class RadioButtonGroup<Choice> extends StatelessWidget {
  final List<Choice> choices;

  final Widget Function(BuildContext context, Choice choice) builder;
  final Widget Function(BuildContext context, List<Widget> children) groupBuilder;

  final Choice selected;
  final ValueChanged<Choice> onChanged;

  static Widget _defaultGroupBuilder(BuildContext context, List<Widget> children) =>
      Row(mainAxisSize: MainAxisSize.min, spacing: 10, children: children);

  const RadioButtonGroup({
    super.key,
    required this.choices,
    required this.builder,
    this.groupBuilder = _defaultGroupBuilder,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => groupBuilder(
        context,
        choices.enumerate().map((el) {
          final (idx, choice) = el;
          return _RadioButton(
            selected: choice == selected,
            onChanged: (value) => onChanged(choice),
            child: builder(context, choice),
          );
        }).toList(),
      );
}

class _RadioButton extends StatelessWidget {
  final Widget child;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _RadioButton({required this.child, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!selected),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? primaryBlue.withAlpha(51) : Colors.transparent,
            border: Border.all(color: selected ? primaryBlue : Colors.grey, width: 1),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: selected ? neonHighlight : terminalText,
            ),
            child: child,
          ),
        ),
      );
}
