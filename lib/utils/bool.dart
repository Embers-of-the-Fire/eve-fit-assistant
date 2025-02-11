extension Bool on bool {
  T? then<T>(T Function() init) {
    if (this) {
      return init();
    } else {
      return null;
    }
  }

  T? thenWith<T>(T init) {
    if (this) {
      return init;
    } else {
      return null;
    }
  }
}
