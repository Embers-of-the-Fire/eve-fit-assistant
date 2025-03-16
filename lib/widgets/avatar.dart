import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';

class BorderedCircleAvatar extends StatelessWidget {
  final ImageProvider? image;
  final IconData? icon;
  final Widget? child;
  final Color? backgroundColor;
  final Color iconColor;
  final double size;
  final double borderWidth;
  final Color borderColor;
  final VoidCallback? onPressed;

  BorderedCircleAvatar({
    super.key,
    this.image,
    this.icon,
    this.child,
    this.backgroundColor,
    this.iconColor = Colors.white,
    this.size = 40.0,
    this.borderWidth = 2.0,
    this.borderColor = Colors.white,
    this.onPressed,
  }) : assert([image, icon, child].countNonNull() <= 1,
            'Only one of `image`, `icon` or `child` should be provided.');

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: size + borderWidth * 2,
      height: size + borderWidth * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: backgroundColor,
        // backgroundImage: image,
        child: child ??
            image.map((u) => Image(image: u)) ??
            icon.map((icon) => Icon(icon, size: size * 0.6, color: iconColor)),
      ),
    );

    return onPressed != null
        ? InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(size),
            child: container,
          )
        : container;
  }
}
