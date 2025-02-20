import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/parse_text/parse_text.dart';
import 'package:flutter/material.dart';

class DescriptionText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const DescriptionText({super.key, required this.text, this.style});

  @override
  State<DescriptionText> createState() => _DescriptionTextState();
}

const _italicRegex = r'<i>(.*?)</i>';
const _boldRegex = r'<b>(.*?)</b>';
const _newLineRegex = r'<br>';
const _showinfoRegex = r'<a href=\"?showinfo:(\d+).*?\"?>(.*?)</a>';

class _DescriptionTextState extends State<DescriptionText> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ParsedText(text: widget.text, style: widget.style, parse: [
      MatchText(
          pattern: _newLineRegex,
          style: const TextStyle(height: 1.5),
          renderText: ({required String str}) => RenderConfig(display: '\n', value: '\n')),
      MatchText(
          pattern: _italicRegex,
          style: const TextStyle(fontStyle: FontStyle.italic),
          renderText: ({required String str}) {
            final match = RegExp(_italicRegex, caseSensitive: false).firstMatch(str);
            if (match == null) return RenderConfig(display: str, value: str);
            return RenderConfig(display: match.group(1)!, value: match.group(1)!);
          }),
      MatchText(
          pattern: _boldRegex,
          style: const TextStyle(fontWeight: FontWeight.bold),
          renderText: ({required String str}) {
            final match = RegExp(_boldRegex, caseSensitive: false).firstMatch(str);
            if (match == null) return RenderConfig(display: str, value: str);
            return RenderConfig(display: match.group(1)!, value: match.group(1)!);
          }),
      MatchText(
          pattern: _showinfoRegex,
          style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
          onTap: (id) => int.tryParse(id).map((u) => showTypeInfoPage(context, typeID: u)),
          renderText: ({required String str}) {
            final match = RegExp(_showinfoRegex, caseSensitive: false).firstMatch(str);
            if (match == null) return RenderConfig(display: str, value: str);
            return RenderConfig(display: match.group(2)!, value: match.group(1)!);
          }),
    ]);
  }
}
