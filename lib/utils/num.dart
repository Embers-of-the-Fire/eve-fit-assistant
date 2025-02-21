part of 'utils.dart';

extension NumIntExt on int {
  int max(int other) => this > other ? this : other;
  int min(int other) => this < other ? this : other;
}

extension NumDoubleExt on double {
  double max(double other) => this > other ? this : other;
  double min(double other) => this < other ? this : other;
}
