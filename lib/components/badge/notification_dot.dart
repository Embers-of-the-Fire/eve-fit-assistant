import "package:flutter/material.dart";

class NotificationDot extends StatelessWidget {
  const NotificationDot({
    required this.child,
    this.count,
    this.dotSize = 8.0,
    this.badgeRadius = 10.0,
    this.color,
    super.key,
  });

  final Widget child;
  final int? count;
  final double dotSize;
  final double badgeRadius;
  final Color? color;

  static const Color _defaultColor = Colors.red;

  @override
  Widget build(BuildContext context) {
    final badge = _buildBadge(context);
    if (badge == null) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(top: -4, right: -4, child: badge),
      ],
    );
  }

  Widget? _buildBadge(BuildContext context) {
    final effectiveColor = color ?? _defaultColor;
    if (count == null) {
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(color: effectiveColor, shape: BoxShape.circle),
      );
    }
    if (count! <= 0) {
      return null;
    }

    final label = count! > 99 ? "99+" : count!.toString();
    return Container(
      constraints: BoxConstraints(minWidth: badgeRadius * 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(badgeRadius),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}
