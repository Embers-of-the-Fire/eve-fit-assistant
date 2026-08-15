import "package:flutter/material.dart";

/// ClickableCircleAvatar uses `CircleAvatar` for rendering and wraps it
/// with `Material` + `InkWell` to provide a circular ripple effect.
/// This simplified version does not include border support.
class ClickableCircleAvatar extends StatelessWidget {
  const ClickableCircleAvatar({
    super.key,
    this.radius = 20.0,
    this.inkWidth = 1.0,
    this.backgroundColor,
    this.backgroundImage,
    this.child,
    this.onTap,
  });

  /// Circle radius
  final double radius;

  /// Ink ripple width
  final double inkWidth;

  /// Background color
  final Color? backgroundColor;

  /// Background image
  final ImageProvider? backgroundImage;

  /// Child widget (takes precedence over initials)
  final Widget? child;

  /// Tap callback
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double r = radius.clamp(0.0, double.infinity);

    final Widget avatar = CircleAvatar(
      radius: r,
      backgroundColor: backgroundColor,
      backgroundImage: backgroundImage,
      child: child,
    );

    final Widget sized = SizedBox(
      width: (r + inkWidth) * 2,
      height: (r + inkWidth) * 2,
      child: Center(child: avatar),
    );

    return Material(
      type: MaterialType.transparency,
      shape: const CircleBorder(),
      child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: sized),
    );
  }
}
