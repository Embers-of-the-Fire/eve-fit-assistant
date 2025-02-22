part of 'utils.dart';

extension StringExt on String {
  Text text({
    Key? key,
    TextStyle? style,
    TextAlign? textAlign,
    TextDirection? textDirection,
    bool? softWrap,
    TextOverflow? overflow,
    int? maxLines,
    StrutStyle? strutStyle,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior,
  }) =>
      Text(
        this,
        key: key,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        strutStyle: strutStyle,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
      );

  TextSpan textSpan(
          {List<InlineSpan>? children,
          TextStyle? style,
          GestureRecognizer? recognizer,
          MouseCursor? mouseCursor,
          void Function(PointerEnterEvent)? onEnter,
          void Function(PointerExitEvent)? onExit,
          String? semanticsLabel,
          Locale? locale,
          bool? spellOut}) =>
      TextSpan(
          text: this,
          children: children,
          style: style,
          recognizer: recognizer,
          mouseCursor: mouseCursor,
          onEnter: onEnter,
          onExit: onExit,
          semanticsLabel: semanticsLabel,
          locale: locale,
          spellOut: spellOut);
}
