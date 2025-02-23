part of 'utils.dart';

extension NumIntExt on int {
  int max(int other) => this > other ? this : other;

  int min(int other) => this < other ? this : other;

  bool flagContains(int other) => (this & other) == other;

  int removeFlag(int other) => (this & other) == other ? this ^ other : this;

  int addFlag(int other) => (this & other) == other ? this : this | other;

  int toggleFlag(int other) => this ^ other;
}

extension NumDoubleExt on double {
  double max(double other) => this > other ? this : other;

  double min(double other) => this < other ? this : other;
}
