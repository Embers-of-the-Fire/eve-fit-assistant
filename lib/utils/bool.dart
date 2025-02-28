part of 'utils.dart';

extension BoolExt on bool {
  T? then<T>(T Function() init) {
    if (this) {
      return init();
    } else {
      return null;
    }
  }

  T? thenSome<T>(T init) {
    if (this) {
      return init;
    } else {
      return null;
    }
  }

  T? thenWith<T>(T? Function() init) {
    if (this) {
      return init();
    } else {
      return null;
    }
  }

  int get asSign => this ? 1 : -1;
}
