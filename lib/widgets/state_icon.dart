import 'package:flutter/material.dart';

enum ItemState {
  passive,
  online,
  active,
  overload;

  factory ItemState.fromInt(int value) => switch (value) {
        0 => ItemState.passive,
        1 => ItemState.online,
        2 => ItemState.active,
        3 => ItemState.overload,
        _ => throw ArgumentError('Invalid ItemState value: $value'),
      };
}

class StateIcon extends StatelessWidget {
  final Widget? child;
  final ImageProvider<Object>? foregroundImage;
  final ItemState state;

  final void Function()? onTap;

  const StateIcon({
    super.key,
    required this.state,
    this.child,
    this.foregroundImage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Ink(
      decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(20))),
      child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          onTap: onTap,
          child: CircleAvatar(
            radius: 20,
            backgroundColor: switch (state) {
              ItemState.active => Colors.green.shade800,
              ItemState.online => Colors.grey.shade400,
              ItemState.overload => Colors.red.shade400,
              ItemState.passive => Theme.of(context).scaffoldBackgroundColor
            },
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade800,
              foregroundImage: foregroundImage,
              child: child,
            ),
          )));
}
