part of 'utils.dart';

extension Lambda<T> on T {
  R let<R>(R Function(T it) block) => block(this);
}
