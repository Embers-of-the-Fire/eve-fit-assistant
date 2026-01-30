import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";

class BorderedRectAvatar extends StatelessWidget {
  const BorderedRectAvatar({
    super.key,
    this.image,
    this.icon,
    this.child,
    this.backgroundColor,
    this.iconColor = Colors.white,
    this.size = 40.0,
    this.borderWidth = 2.0,
    this.borderColor = Colors.white,
    this.onTap,
  });

  final ImageProvider? image;
  final IconData? icon;
  final Widget? child;
  final Color? backgroundColor;
  final Color iconColor;
  final double size;
  final double borderWidth;
  final Color borderColor;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: size + borderWidth * 2,
      height: size + borderWidth * 2,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: backgroundColor),
        child:
            child ??
            image.map((u) => Image(image: u, fit: BoxFit.cover)) ??
            icon.map((i) => Icon(icon, size: size * 0.6, color: iconColor)),
      ),
    );

    return onTap != null ? GestureDetector(onTap: onTap, child: container) : container;
  }
}
