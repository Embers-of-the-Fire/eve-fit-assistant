import "package:flutter/material.dart";

/// The shared green/orange/red steps used by resource usage displays.
///
/// Returns [Colors.red] when [used] exceeds [all], [Colors.orange] when
/// [warning] is set and usage passes 90%, and [Colors.green] otherwise.
Color resourceUsageColor(double used, double all, {bool warning = true}) {
  if (used > all) {
    return Colors.red;
  }
  if (warning && used > all * 0.9) {
    return Colors.orange;
  }
  return Colors.green;
}

/// A thin usage bar visualizing the ratio of [used] to [all].
///
/// The fill follows the same green/orange/red steps as [resourceUsageColor],
/// but unlike the text it is clamped to the bar width when [used] exceeds
/// [all]. Colors can be overridden via [usedColor] and [trackColor].
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

  /// Whether the fill turns [Colors.orange] as usage approaches [all].
  ///
  /// When false, the fill stays green until [used] exceeds [all].
  final bool warning;

  /// Overrides the default green/orange/red fill color.
  final Color? usedColor;

  /// Overrides the default neutral track color.
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final fraction = all <= 0 ? 0.0 : (used / all).clamp(0.0, 1.0);
    final fill = usedColor ?? resourceUsageColor(used, all, warning: warning);
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
}
