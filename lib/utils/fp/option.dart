part of '../fp.dart';

extension BoolThen on bool {
  Option<T> thenSome<T>(T value) => this ? Some(value) : None();

  Option<T> then<T>(T Function() value) => this ? Some(value()) : None();
}

extension Flatten<T> on Option<T>? {
  Option<T> flatten() {
    if (this == null) {
      return None();
    }
    return this!;
  }
}

extension Unwrap<T> on Option<T> {
  T unwrap([String? hint]) {
    final stackTrace = StackTrace.current;
    return match(() {
      final errorText = hint == null
          ? "Unwrapping an `Option.none`"
          : "Unwrapping an `Option.none`: $hint";
      error(errorText, stackTrace: stackTrace);
      throw Exception(errorText);
    }, (value) => value);
  }
}
