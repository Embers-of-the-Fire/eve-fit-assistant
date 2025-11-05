/// Explicit source with `dynamic` type to satisfy type checker
// ignore: avoid_annotating_with_dynamic
T ensure<T>(dynamic source, T defaultValue) => source is T ? source : defaultValue;

extension UnawaitedPostfix<T> on Future<T> {
  void get unawaited {}
}
