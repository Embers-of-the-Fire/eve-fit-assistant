import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";

enum ResonanceType {
  em,
  thermal,
  kinetic,
  explosive;

  Color get color => switch (this) {
    ResonanceType.em => Colors.blue,
    ResonanceType.thermal => Colors.red,
    ResonanceType.kinetic => Colors.grey,
    ResonanceType.explosive => Colors.orange,
  };
}

class ResonanceBox extends StatelessWidget {
  const ResonanceBox({required this.ratio, required this.type, super.key});

  /// Raw value, 1 - ratio = actual display value
  final double ratio;
  final ResonanceType type;

  @override
  Widget build(BuildContext context) => Container(
    margin: const .symmetric(vertical: 4, horizontal: 10),
    height: 22,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white),
      gradient: (ratio > 0).thenSome(
        LinearGradient(colors: [type.color, Colors.black], stops: [1 - ratio, 1 - ratio]),
      ),
    ),
    child: Text("${((1 - ratio) * 100).round()}%"),
  );
}
