import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';

class ResourceCompare extends StatelessWidget {
  final double used;
  final double all;
  final bool warning;

  /// The fixed number of decimal places to show.
  final int fixed;

  /// The unit of the resource.
  final String? unit;

  final MainAxisAlignment? alignment;

  const ResourceCompare({
    super.key,
    required this.used,
    required this.all,
    this.warning = true,
    this.fixed = 0,
    this.unit,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final used = this.used.toStringAsFixed(fixed);
    final all = this.all.toStringAsFixed(fixed);
    final unit = this.unit.map((u) => ' $u').unwrapOr('');

    return Row(
      mainAxisAlignment: alignment ?? MainAxisAlignment.start,
      children: [
        Text(used, style: TextStyle(color: _getColorFromValue(this.used, this.all, warning))),
        Text('/$all$unit'),
      ],
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
