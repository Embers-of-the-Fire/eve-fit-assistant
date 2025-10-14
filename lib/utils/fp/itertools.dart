part of '../fp.dart';

extension Enumerate<T> on Iterable<T> {
  Iterable<(int, T)> enumerate([int start = 0]) sync* {
    int index = start;
    for (final element in this) {
      yield (index, element);
      index++;
    }
  }
}

extension FilterNull<T> on Iterable<T?> {
  Iterable<T> filterNull() sync* {
    for (final element in this) {
      if (element != null) {
        yield element;
      }
    }
  }
}
