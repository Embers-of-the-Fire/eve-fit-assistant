part of 'utils.dart';

extension WidgetStatePropertyConstructorExt<T> on T {
  WidgetStateProperty<T> get widgetStateProperty => WidgetStatePropertyAll(this);
}
