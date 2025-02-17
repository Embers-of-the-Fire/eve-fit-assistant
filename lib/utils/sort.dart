part of 'utils.dart';

class Reversed<R extends Comparable<R>> implements Comparable<Reversed<R>> {
  final R _raw;

  const Reversed(this._raw);

  @override
  int compareTo(Reversed<R> other) => other._raw.compareTo(_raw);
}
