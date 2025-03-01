import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DescriptionText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const DescriptionText({super.key, required this.text, this.style});

  @override
  State<DescriptionText> createState() => _DescriptionTextState();
}

class _DescriptionTextState extends State<DescriptionText> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final text = widget.text.replaceAllMapped(
      RegExp(r'<url=([^>]+)>([^<]+)</url>'),
      (match) => '<url href="${match.group(1)}">${match.group(2)}</url>',
    );
    final html = parseFragment('<div>$text</div>');
    return SelectableText.rich(
      _buildFromNode(context, html),
      style: const TextStyle(fontSize: 18),
    );
  }
}

TextSpan _buildFromNode(BuildContext context, html.Node node) => switch (node) {
      html.Text(:final data) => TextSpan(text: data),
      html.Element() => _buildFromElement(context, node),
      html.Node() => TextSpan(children: node.nodes.map((u) => _buildFromNode(context, u)).toList()),
    };

TextSpan _buildFromElement(BuildContext context, html.Element element) {
  TextSpan Function(html.NodeList) any(TextSpan Function(List<TextSpan>) builder) =>
      (children) => builder(children.map((u) => _buildFromNode(context, u)).toList());

  final TextSpan Function(html.NodeList) builder = switch (element.localName) {
    'i' => any((ch) => TextSpan(children: ch, style: const TextStyle(fontStyle: FontStyle.italic))),
    'b' => any((ch) => TextSpan(children: ch, style: const TextStyle(fontWeight: FontWeight.bold))),
    'br' => (_) => const TextSpan(text: '\n'),
    'font' => any((ch) => TextSpan(
          children: ch,
          style: TextStyle(
            color: element.attributes['color']
                .andThen((u) => int.tryParse(u.replaceAll('#', ''), radix: 16))
                .map((u) => Color(u)),
            fontSize:
                element.attributes['size'].andThen((u) => double.tryParse(u)).map((u) => u * 1.5),
          ),
        )),
    'url' => (ch) => TextSpan(
        text: ch.map((u) => u.text).join(''),
        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()
          ..onTap = () => element.attributes['href']
              .andThen((u) => launchUrlString(u, mode: LaunchMode.externalApplication))),
    'a' => (ch) => TextSpan(
        text: ch.map((u) => u.text).join(''),
        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()
          ..onTap = () => element.attributes['href']
              .andThen((u) => int.tryParse(u.replaceAll('showinfo:', '')))
              .andThen((u) => showTypeInfoPage(context, typeID: u))),
    _ => any((ch) => TextSpan(children: ch)),
  };

  return builder(element.nodes);
}
