import "package:efa_component/src/bordered_avatar.dart";
import "package:efa_component/src/colors.dart";
import "package:flutter/material.dart";

/// Activation state of a fit item, mirrored from the app's storage schema and
/// the `Slots.SlotState` protobuf enum.
enum EfaItemState { passive, online, active, overload }

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
    required EfaItemState state,
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
    required EfaItemState state,
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

  final EfaItemState state;
  final bool isCircle;
  final void Function()? onTap;
  final double size;

  final ImageProvider? image;
  final IconData? icon;
  final Widget? child;

  Color get _borderColor => switch (state) {
    EfaItemState.active => colorStatusActive,
    EfaItemState.online => colorStatusOnline,
    EfaItemState.overload => colorStatusOverload,
    EfaItemState.passive => colorStatusPassive,
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
