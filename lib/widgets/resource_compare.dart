import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';

class ResourceCompare extends StatelessWidget {
  final double used;
  final double all;
  final bool warning;

  final TextAlign? align;

  /// The fixed number of decimal places to show.
  final int fixed;

  /// The unit of the resource.
  final String? unit;

  const ResourceCompare({
    super.key,
    required this.used,
    required this.all,
    this.align,
    this.warning = true,
    this.fixed = 0,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final used = this.used.toStringAsFixed(fixed);
    final all = this.all.toStringAsFixed(fixed);
    final unit = this.unit.map((u) => ' $u').unwrapOr('');

    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: used, style: TextStyle(color: _getColorFromValue(this.used, this.all, warning))),
        TextSpan(text: '/$all$unit'),
      ]),
      textAlign: align,
    );
  }
}

Color _getColorFromValue(double value, double max, bool warning) {
  if (value > max) {
    return Colors.red;
  } else if (warning && value > max * 0.9) {
    return Colors.orange;
  } else {
    return Colors.green;
  }
}
