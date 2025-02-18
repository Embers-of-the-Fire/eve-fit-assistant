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
    var sum = 0;
    for (final e in this) {
      sum += e;
    }
    return sum;
  }
}

extension ItertoolDouble on Iterable<double> {
  double sum() {
    var sum = 0.0;
    for (final e in this) {
      sum += e;
    }
    return sum;
  }
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
