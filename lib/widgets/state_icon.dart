import 'package:eve_fit_assistant/theme/color.dart';
import 'package:eve_fit_assistant/widgets/avatar.dart';
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
  final ImageProvider<Object>? foregroundImage;
  final ItemState state;

  final void Function()? onTap;

  const StateIcon({
    super.key,
    required this.state,
    this.foregroundImage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => BorderedCircleAvatar(
        size: 35,
        onPressed: onTap,
        borderColor: switch (state) {
          ItemState.active => colorStatusActive,
          ItemState.online => colorStatusOnline,
          ItemState.overload => colorStatusOverload,
          ItemState.passive => colorStatusPassive,
        },
        backgroundColor: colorStatusPassive,
        image: foregroundImage,
      );
}
