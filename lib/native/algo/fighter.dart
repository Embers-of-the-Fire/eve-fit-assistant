import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/static/fighter.dart';
import 'package:eve_fit_assistant/storage/storage.dart';

/// Returns: (light, support, heavy)
(int, int, int) countFighter(FitRecord fit) {
  int light = 0;
  int support = 0;
  int heavy = 0;

  for (final fighter in fit.body.fighter) {
    final type = GlobalStorage().static.fighters[fighter.itemID]?.type;

    final _ = switch (type) {
      FighterType.light => light++,
      FighterType.support => support++,
      FighterType.heavy => heavy++,
      _ => null,
    };
  }

  return (light, support, heavy);
}
