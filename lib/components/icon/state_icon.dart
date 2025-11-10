import "package:eve_fit_assistant/components/icon/bordered_circle_avatar.dart";
import "package:eve_fit_assistant/components/icon/bordered_rect_avatar.dart";
import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter/material.dart";

class StateIcon extends StatelessWidget {
  const StateIcon._({
    required this.state,
    required this.isCircle,
    super.key,
    this.image,
    this.icon,
    this.child,
    this.onTap,
    this.size = 35,
  });

  const StateIcon.circle({
    required FitItemState state,
    Key? key,
    ImageProvider? image,
    IconData? icon,
    Widget? child,
    void Function()? onTap,
    double size = 35,
  }) : this._(
          state: state,
          isCircle: true,
          key: key,
          image: image,
          icon: icon,
          child: child,
          onTap: onTap,
          size: size,
        );

  const StateIcon.rect({
    required FitItemState state,
    Key? key,
    ImageProvider? image,
    IconData? icon,
    Widget? child,
    void Function()? onTap,
    double size = 35,
  }) : this._(
          state: state,
          isCircle: false,
          key: key,
          image: image,
          icon: icon,
          child: child,
          onTap: onTap,
          size: size,
        );

  final FitItemState state;
  final bool isCircle;
  final void Function()? onTap;
  final double size;

  final ImageProvider? image;
  final IconData? icon;
  final Widget? child;

  Color get _borderColor => switch (state) {
        FitItemState.active => colorStatusActive,
        FitItemState.online => colorStatusOnline,
        FitItemState.overload => colorStatusOverload,
        FitItemState.passive => colorStatusPassive,
      };

  @override
  Widget build(BuildContext context) {
    if (isCircle) {
      return BorderedCircleAvatar(
        size: size,
        onTap: onTap,
        borderColor: _borderColor,
        backgroundColor: colorStatusPassive,
        image: image,
        icon: icon,
        child: child,
      );
    } else {
      return BorderedRectAvatar(
        size: size,
        onTap: onTap,
        borderColor: _borderColor,
        backgroundColor: colorStatusPassive,
        image: image,
        icon: icon,
        child: child,
      );
    }
  }
}
