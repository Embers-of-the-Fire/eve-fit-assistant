import 'package:flutter/material.dart';

class LabeledSwitch extends StatefulWidget {
  final String leftText;
  final String rightText;
  final TextStyle? textStyle;
  final ValueChanged<bool> onChanged;

  const LabeledSwitch({
    super.key,
    required this.leftText,
    required this.rightText,
    this.textStyle,
    required this.onChanged,
  });

  @override
  State<LabeledSwitch> createState() => _LabeledSwitchState();
}

class _LabeledSwitchState extends State<LabeledSwitch> {
  bool _switchValue = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          setState(() {
            _switchValue = !_switchValue;
            widget.onChanged(_switchValue);
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.leftText, style: widget.textStyle),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Switch(
                value: _switchValue,
                onChanged: (value) {
                  setState(() {
                    _switchValue = value;
                    widget.onChanged(value);
                  });
                },
                activeColor: Colors.blue,
                activeTrackColor: Colors.blue[100],
              ),
            ),
            Text(widget.rightText, style: widget.textStyle),
          ],
        ),
      );
}
