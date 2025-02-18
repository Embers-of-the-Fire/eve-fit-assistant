import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';

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
  /// Raw value, 1 - ratio = actual display value
  final double ratio;
  final ResonanceType type;

  const ResonanceBox({
    super.key,
    required this.ratio,
    required this.type,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        height: 22,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white),
          gradient: (ratio > 0).thenSome(LinearGradient(
            colors: [type.color, Colors.black],
            stops: [1 - ratio, 1 - ratio],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          )),
        ),
        child: Text('${((1 - ratio) * 100).round()}%'),
      );
}
