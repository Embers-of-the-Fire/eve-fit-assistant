import "package:eve_fit_assistant/components/icon/bordered_circle_avatar.dart";
import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter/material.dart";

class StateIcon extends StatelessWidget {
  const StateIcon({required this.state, super.key, this.image, this.icon, this.child, this.onTap});

  final FitItemState state;
  final void Function()? onTap;

  final ImageProvider? image;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) => BorderedCircleAvatar(
    size: 35,
    onTap: onTap,
    borderColor: switch (state) {
      FitItemState.active => colorStatusActive,
      FitItemState.online => colorStatusOnline,
      FitItemState.overload => colorStatusOverload,
      FitItemState.passive => colorStatusPassive,
    },
    backgroundColor: colorStatusPassive,
    image: image,
    icon: icon,
    child: child,
  );
}
