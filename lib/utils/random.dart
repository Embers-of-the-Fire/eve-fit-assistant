part of 'utils.dart';

extension RandomExt on Random {
  double nextDoubleRange(double min, double max) => nextDouble() * (max - min) + min;

  int nextIntRange(int min, int max) => nextInt(max - min) + min;
}
