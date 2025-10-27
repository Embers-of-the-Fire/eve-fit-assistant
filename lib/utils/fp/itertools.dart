part of "../fp.dart";

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

extension FilterNone<T> on Iterable<Option<T>> {
  Iterable<T> filterNone() sync* {
    for (final element in this) {
      switch (element) {
        case Some(:final value):
          yield value;
        case None():
          continue;
      }
    }
  }
}

Iterable<int> range(int start, int end) sync* {
  for (int i = start; i < end; i++) {
    yield i;
  }
}

extension Windowed<T> on Iterable<T> {
  Iterable<(T, T?)> window2() sync* {
    final buffer = <T?>[];
    for (final element in this) {
      buffer.add(element);
      if (buffer.length == 2) {
        yield (buffer[0]!, buffer[1]);
        buffer.removeAt(0);
      }
    }
    if (buffer.isNotEmpty) {
      yield (buffer[0]!, null);
    }
  }
}

extension RepeatElement<T> on T {
  Iterable<T> repeat(int count) sync* {
    for (int i = 0; i < count; i++) {
      yield this;
    }
  }
}

// Explicitly allow dynamic to make it easier to use in debug scenarios
// ignore: avoid_annotating_with_dynamic
void _defaultInspect(dynamic element) {
  debugPrint("$element");
}

extension Inspect<T> on Iterable<T> {
  Iterable<T> inspect([void Function(T) inspectFn = _defaultInspect]) sync* {
    for (final element in this) {
      inspectFn(element);
      yield element;
    }
  }
}
