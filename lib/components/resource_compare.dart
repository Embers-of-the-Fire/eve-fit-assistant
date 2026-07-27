import "package:eve_fit_assistant/components/resource_bar.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";

class ResourceCompare extends StatelessWidget {
  const ResourceCompare({
    required this.used,
    required this.all,
    super.key,
    this.unit,
    this.align,
    this.warning = true,
    this.fixed = 0,
    this.bar = false,
    this.barHeight = 4,
    this.barUsedColor,
    this.barTrackColor,
  });
  final double used;
  final double all;
  final bool warning;

  final TextAlign? align;

  /// The fixed number of decimal places to show.
  final int fixed;

  /// The unit of the resource.
  final String? unit;

  /// Whether to draw a usage bar below the text.
  final bool bar;

  /// The thickness of the usage bar.
  final double barHeight;

  /// Overrides the default green~red fill color of the usage bar.
  final Color? barUsedColor;

  /// Overrides the default neutral track color of the usage bar.
  final Color? barTrackColor;

  @override
  Widget build(BuildContext context) {
    final used = this.used.toStringAsFixed(fixed);
    final all = this.all.toStringAsFixed(fixed);
    final unit = this.unit.map((u) => " $u").or("");

    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: used,
            style: TextStyle(color: _getColorFromValue(this.used, this.all, warning)),
          ),
          TextSpan(text: "/$all$unit"),
        ],
      ),
      textAlign: align,
    );

    if (!bar) {
      return text;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        text,
        const SizedBox(height: 4),
        ResourceBar(
          used: this.used,
          all: this.all,
          warning: warning,
          height: barHeight,
          usedColor: barUsedColor,
          trackColor: barTrackColor,
        ),
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
