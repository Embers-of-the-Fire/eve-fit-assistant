import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";

class BorderedCircleAvatar extends StatelessWidget {
  const BorderedCircleAvatar({
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
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: backgroundColor,
        child:
            child ??
            image.map((u) => ClipOval(child: Image(image: u))) ??
            icon.map((i) => Icon(icon, size: size * 0.6, color: iconColor)),
      ),
    );

    return onTap != null ? GestureDetector(onTap: onTap, child: container) : container;
  }
}
