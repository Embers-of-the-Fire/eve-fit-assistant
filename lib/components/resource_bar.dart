import "package:eve_fit_assistant/components/color.dart";
import "package:flutter/material.dart";

/// A thin usage bar visualizing the ratio of [used] to [all].
///
/// The fill slides from green to red as usage grows by default and turns
/// solid red when [used] exceeds [all]. Colors can be overridden via
/// [usedColor] and [trackColor].
class ResourceBar extends StatelessWidget {
  const ResourceBar({
    required this.used,
    required this.all,
    super.key,
    this.height = 4,
    this.warning = true,
    this.usedColor,
    this.trackColor,
  });

  final double used;
  final double all;

  /// The thickness of the bar.
  final double height;

  /// Whether the fill warms up towards red as it approaches [all].
  ///
  /// When false, the fill stays green until [used] exceeds [all].
  final bool warning;

  /// Overrides the default green~red fill color.
  final Color? usedColor;

  /// Overrides the default neutral track color.
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final fraction = all <= 0 ? 0.0 : (used / all).clamp(0.0, 1.0);
    final fill = usedColor ?? _defaultFill(fraction, used > all);
    final track = trackColor ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15);

    return LayoutBuilder(
      builder: (context, constraints) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: track),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: 0,
                top: 0,
                bottom: 0,
                width: constraints.maxWidth * fraction,
                child: ColoredBox(color: fill),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _defaultFill(double fraction, bool overloaded) {
    if (overloaded) {
      return Colors.red;
    }
    if (!warning) {
      return colorGreen;
    }
    return Color.lerp(colorGreen, Colors.red, fraction)!;
  }
}
