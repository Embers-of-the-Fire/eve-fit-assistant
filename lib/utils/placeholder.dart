part of 'utils.dart';

extension PlaceholderExt<T extends Widget> on T? {
  Widget orShrink() => this ?? const SizedBox.shrink();

  Widget orBox({double? width, double? height}) =>
      this ?? SizedBox(width: width, height: height);

  Widget orBoxedPlaceholder({double? width, double? height}) =>
      this ?? Placeholder(fallbackHeight: height ?? 400.0, fallbackWidth: width ?? 400.0);
}
