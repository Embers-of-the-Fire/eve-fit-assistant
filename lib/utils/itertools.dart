part of 'utils.dart';

extension Itertools<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) predicate) sync* {
    for (final e in this) {
      if (predicate(e)) {
        yield e;
      }
    }
  }

  Iterable<T> sortedByKey<R extends Comparable<R>>(R Function(T) key) sync* {
    final list = toList();
    list.sort((a, b) => key(a).compareTo(key(b)));
    yield* list;
  }

  Iterable<U> filterMap<U>(U? Function(T) f) => map(f).filter((e) => e != null).map((e) => e!);

  Iterable<(int, T)> enumerate() sync* {
    var index = 0;
    for (final e in this) {
      yield (index, e);
      index++;
    }
  }

  Iterable<T> chain(Iterable<T> next) sync* {
    yield* this;
    yield* next;
  }

  Iterable<U> flatMap<U>(Iterable<U> Function(T) f) sync* {
    for (final e in this) {
      yield* f(e);
    }
  }

  Map<K, List<T>> groupBy<K>(K Function(T) key) {
    final map = <K, List<T>>{};
    for (final e in this) {
      final k = key(e);
      if (!map.containsKey(k)) {
        map[k] = [];
      }
      map[k]!.add(e);
    }
    return map;
  }

  Iterable<T> pad(int size, T pad) sync* {
    yield* this;
    for (var i = 0; i < size - length; i++) {
      yield pad;
    }
  }

  Iterable<T?> padNull(int size) sync* {
    yield* this;
    for (var i = 0; i < size - length; i++) {
      yield null;
    }
  }

  Iterable<Iterable<T>> chunk(int size) sync* {
    final list = toList();
    for (var i = 0; i < list.length; i += size) {
      yield list.skip(i).take(size);
    }
  }

  Iterable<Iterable<T>> chunkPad(int size, T pad) sync* {
    final list = toList();
    for (var i = 0; i < list.length; i += size) {
      yield list.skip(i).take(size).pad(size, pad);
    }
  }

  Iterable<Iterable<T?>> chunkNullPad(int size) sync* {
    final list = toList();
    for (var i = 0; i < list.length; i += size) {
      yield list.skip(i).take(size).padNull(size);
    }
  }

  Iterable<T> unique() sync* {
    final set = <T>{};
    for (final e in this) {
      if (set.add(e)) {
        yield e;
      }
    }
  }

  Iterable<T> uniqueBy<R>(R Function(T) key) sync* {
    final set = <R>{};
    for (final e in this) {
      if (set.add(key(e))) {
        yield e;
      }
    }
  }

  int count() {
    var count = 0;
    for (final _ in this) {
      count++;
    }
    return count;
  }

  T? find(bool Function(T) predicate) {
    for (final e in this) {
      if (predicate(e)) {
        return e;
      }
    }
    return null;
  }
}

extension ItertoolInt on Iterable<int> {
  int sum() {
    int sum = 0;
    for (final e in this) {
      sum += e;
    }
    return sum;
  }

  int? get max => (this as Iterable<num>).max as int?;

  int get nextPossible {
    int i = 0;
    for (final e in this) {
      if (e == i) {
        i++;
      } else {
        break;
      }
    }
    return i;
  }
}

extension ItertoolDouble on Iterable<double> {
  double sum() {
    double sum = 0.0;
    for (final e in this) {
      sum += e;
    }
    return sum;
  }

  double? get max => (this as Iterable<num>).max as double?;
}

extension ItertoolFlatten<T> on Iterable<Iterable<T>> {
  Iterable<T> flatten() sync* {
    for (final e in this) {
      yield* e;
    }
  }
}

extension ItertoolMap<K extends Comparable<K>, V> on Map<K, V> {
  Iterable<MapEntry<K, V>> sorted() => entries.sortedByKey((i) => i.key);
}

extension ItertoolComparable<T extends Comparable<T>> on Iterable<T> {
  T? get max {
    T? max;
    for (final e in this) {
      if (max == null || e.compareTo(max) > 0) {
        max = e;
      }
    }
    return max;
  }

  T? get min {
    T? min;
    for (final e in this) {
      if (min == null || e.compareTo(min) < 0) {
        min = e;
      }
    }
    return min;
  }
}
