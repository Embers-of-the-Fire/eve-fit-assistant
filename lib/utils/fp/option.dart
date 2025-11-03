part of "../fp.dart";

extension MonadBoolThen on bool {
  Option<T> thenSomeM<T>(T value) => this ? Some(value) : const None();

  Option<T> thenM<T>(T Function() value) => this ? Some(value()) : const None();
}

extension PlainBoolThen on bool {
  T? thenSome<T>(T value) => this ? value : null;
  T? then<T>(T Function() value) => this ? value() : null;
}

extension Flatten<T> on Option<T>? {
  Option<T> flatten() {
    if (this == null) {
      return const None();
    }
    return this!;
  }
}

extension Unwrap<T> on Option<T> {
  T unwrap([String? hint]) {
    assert(() {
      final stackTrace = StackTrace.current;
      final errorText = hint == null
          ? "Unwrapping an `Option.none`"
          : "Unwrapping an `Option.none`: $hint";
      error(errorText, stackTrace: stackTrace, error: Exception(errorText));
      return true;
    }());
    return match(() {
      throw Exception(
        hint == null ? "Unwrapping an `Option.none`" : "Unwrapping an `Option.none`: $hint",
      );
    }, (value) => value);
  }
}

extension Optional<T> on T? {
  Option<T> get optional => Option.fromNullable(this);
}

extension Nullable<T> on Option<T> {
  T? get nullable => toNullable();
}

extension MapMonad<T> on T? {
  R? map<R>(R Function(T value) f) {
    if (this == null) {
      return null;
    }
    return f(this as T);
  }
}

extension MapAndThen<T> on T? {
  R? andThen<R>(R? Function(T value) f) {
    if (this == null) {
      return null;
    }
    return f(this as T);
  }
}

extension MapOrElse<T> on T? {
  R mapOrElse<R>(R Function(T value) f, R Function() orElse) {
    if (this == null) {
      return orElse();
    }
    return f(this as T);
  }
}

extension NullableOrElse<T> on T? {
  T orElse(T Function() value) => this ?? value();
  T? tryOrElse(T? Function() value) => this ?? value();
}
