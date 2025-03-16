part of 'utils.dart';

extension Optional<T> on T? {
  U? map<U>(U Function(T value) f) {
    if (this == null) {
      return null;
    } else {
      return f(this as T);
    }
  }

  U? andThen<U>(U? Function(T value) f) {
    if (this == null) {
      return null;
    } else {
      return f(this as T);
    }
  }

  T unwrapOr(T defaultValue) {
    if (this == null) {
      return defaultValue;
    } else {
      return this as T;
    }
  }

  U mapOrElse<U>({
    required U Function(T value) map,
    required U Function() orElse,
  }) {
    if (this == null) {
      return orElse();
    } else {
      return map(this as T);
    }
  }

  bool isSomeAnd(bool Function(T value) f) {
    if (this == null) {
      return false;
    } else {
      return f(this as T);
    }
  }

  T? mFilter(bool Function(T value) f) {
    if (this == null) {
      return null;
    } else {
      final value = this as T;
      if (f(value)) {
        return value;
      } else {
        return null;
      }
    }
  }

  T? mInspect([String name = '']) {
    if (this != null) {
      log('$this', name: name);
    } else {
      log('<null>', name: name);
    }
    return this;
  }

  Future<T?> get async async => this;
}

extension Inspect<T> on T {
  T inspect([String name = '']) {
    log('$this', name: name);
    return this;
  }
}

extension AsyncOptional<T> on Future<T?> {
  Future<U?> map<U>(U Function(T value) f) async {
    final value = await this;
    if (value == null) {
      return null;
    } else {
      return f(value);
    }
  }

  Future<U?> andThen<U>(Future<U?> Function(T value) f) async {
    final value = await this;
    if (value == null) {
      return null;
    } else {
      return f(value);
    }
  }
}

extension OptionalAsync<T> on Future<T>? {
  Future<T?> get transpose {
    if (this == null) {
      return Future.value(null);
    } else {
      return this!;
    }
  }
}

extension ZeroOptionalInt on int {
  int? get optional => this == 0 ? null : this;
}

extension ZeroOptionalDouble on double {
  double? get optional => this == 0 ? null : this;
}

extension ZeroOptionalString on String {
  String? get optional => isEmpty ? null : this;
}
