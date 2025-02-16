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

  Future<T?> async() async => this;
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
