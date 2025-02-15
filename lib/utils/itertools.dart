extension Itertools<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) predicate) => _FilterIterable(this, predicate);

  Iterable<T> sortedByKey<R extends Comparable<R>>(R Function(T) key) =>
      _SortedByKeyIterable(this, key);

  Iterable<U> filterMap<U>(U? Function(T) f) => map(f).filter((e) => e != null).map((e) => e!);

  Iterable<(int, T)> enumerate() => _EnumerateIterable(this);

  Iterable<T> chain(Iterable<T> next) => _ChainIterable(this, next);

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

class _FilterIterable<T> with Iterable<T> {
  final Iterable<T> _internal;
  final bool Function(T) _predicate;

  const _FilterIterable(this._internal, this._predicate);

  @override
  Iterator<T> get iterator => _FilterIterator(this._internal.iterator, this._predicate);
}

class _FilterIterator<T> implements Iterator<T> {
  final Iterator<T> _internal;
  final bool Function(T) _predicate;

  _FilterIterator(this._internal, this._predicate);

  @override
  T get current => _internal.current;

  @override
  bool moveNext() {
    while (_internal.moveNext()) {
      if (_internal.current != null && _predicate(_internal.current)) {
        return true;
      }
    }
    return false;
  }
}

class _SortedByKeyIterable<T, R extends Comparable<R>> with Iterable<T> {
  final Iterable<T> _internal;
  final R Function(T) _key;

  const _SortedByKeyIterable(this._internal, this._key);

  @override
  Iterator<T> get iterator {
    final list = _internal.toList();
    list.sort((a, b) => _key(a).compareTo(_key(b)));
    return list.iterator;
  }
}

class _EnumerateIterable<T> with Iterable<(int, T)> {
  final Iterable<T> _internal;

  const _EnumerateIterable(this._internal);

  @override
  Iterator<(int, T)> get iterator => _EnumerateIterator(this._internal.iterator);
}

class _EnumerateIterator<T> implements Iterator<(int, T)> {
  final Iterator<T> _internal;
  int _index = -1;

  _EnumerateIterator(this._internal);

  @override
  (int, T) get current => (_index, _internal.current);

  @override
  bool moveNext() {
    if (_internal.moveNext()) {
      _index++;
      return true;
    }
    return false;
  }
}

class _ChainIterable<T> with Iterable<T> {
  final Iterable<T> base;
  final Iterable<T> next;

  const _ChainIterable(this.base, this.next);

  @override
  Iterator<T> get iterator => _ChainIterator(base.iterator, next.iterator);
}

class _ChainIterator<T> implements Iterator<T> {
  Iterator<T> base;
  Iterator<T>? next;

  _ChainIterator(this.base, this.next);

  @override
  T get current => base.current;

  @override
  bool moveNext() {
    if (base.moveNext()) {
      return true;
    }
    if (next != null) {
      base = next!;
      next = null;
      return base.moveNext();
    }
    return false;
  }
}
