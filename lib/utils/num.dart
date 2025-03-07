part of 'utils.dart';

extension NumIntExt on int {
  int max(int other) => this > other ? this : other;

  int min(int other) => this < other ? this : other;

  bool flagContains(int other) => (this & other) == other;

  int removeFlag(int other) => (this & other) == other ? this ^ other : this;

  int addFlag(int other) => (this & other) == other ? this : this | other;

  int toggleFlag(int other) => this ^ other;

  String get separate {
    final str = toString();
    final integerList = <String>[];
    for (int i = str.length - 1; i >= 0; i--) {
      integerList.add(str[i]);
      if ((str.length - i) % 3 == 0 && i != 0) {
        integerList.add(',');
      }
    }
    return integerList.reversed.join();
  }
}

extension NumDoubleExt on double {
  double max(double other) => this > other ? this : other;

  double min(double other) => this < other ? this : other;
}

extension NumExt on num {
  String toStringAsMaxDecimals(int maxDecimals) {
    final str = toStringAsFixed(maxDecimals);
    final dotIndex = str.indexOf('.');
    if (dotIndex == -1) return str;
    final decimals = str.substring(dotIndex + 1);
    if (decimals.length <= maxDecimals) return str;
    return str.substring(0, dotIndex + 1 + maxDecimals);
  }

  String get moneyFormat {
    final str = toStringAsFixed(2);
    final dotIndex = str.indexOf('.');
    final integer = str.substring(0, dotIndex);
    final decimal = str.substring(dotIndex + 1);
    final integerList = <String>[];
    for (int i = integer.length - 1; i >= 0; i--) {
      integerList.add(integer[i]);
      if ((integer.length - i) % 3 == 0 && i != 0) {
        integerList.add(',');
      }
    }
    return '${integerList.reversed.join()}.$decimal';
  }
}
