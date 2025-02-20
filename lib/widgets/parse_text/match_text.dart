part of 'parse_text.dart';

class RenderConfig {
  final String display;
  final dynamic value;

  RenderConfig({
    required this.display,
    required this.value,
  });
}

/// A MatchText class which provides a structure for [ParsedText] to handle
/// Pattern matching and also to provide custom [Function] and custom [TextStyle].
class MatchText {
  String? pattern;

  /// Takes a custom style of [TextStyle] for the matched text widget
  TextStyle? style;

  /// A custom [Function] to handle onTap.
  Function(dynamic)? onTap;

  /// A callback function that takes two parameter String & pattern
  ///
  /// @param str - is the word that is being matched
  /// @param pattern - pattern passed to the MatchText class
  ///
  /// eg: Your str is 'Mention [@michel:5455345]' where 5455345 is ID of this user
  /// and @michel the value to display on interface.
  /// Your pattern for ID & username extraction : `/\[(@[^:]+):([^\]]+)\]/`i
  /// Displayed text will be : Mention `@michel`
  RenderConfig Function({required String str})? renderText;

  /// Creates a MatchText object
  MatchText({
    this.pattern,
    this.style,
    this.onTap,
    this.renderText,
  });
}
