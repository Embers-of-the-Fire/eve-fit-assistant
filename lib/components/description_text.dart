import "package:eve_fit_assistant/pages/item-detail/page.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:html/dom.dart" as html;
import "package:html/parser.dart" as html_parser;
import "package:url_launcher/url_launcher.dart";

// ignore: avoid_private_typedef_functions
typedef _LinkHandler = Future<void> Function(BuildContext context, Uri uri);

const _linkHandlers = <String, _LinkHandler>{
  "showinfo": _handleShowInfo,
  "http": _handleExternalUrl,
  "https": _handleExternalUrl,
};

class DescriptionText extends StatefulWidget {
  const DescriptionText({required this.text, super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<DescriptionText> createState() => _DescriptionTextState();
}

class _DescriptionTextState extends State<DescriptionText>
    with AutomaticKeepAliveClientMixin<DescriptionText> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final normalizedText = widget.text.replaceAllMapped(
      RegExp("<url=([^>]+)>"),
      (match) => '<url href="${match.group(1)}">',
    );
    final fragment = html_parser.parseFragment("<div>$normalizedText</div>");

    return SelectableText.rich(_buildFromNode(context, fragment), style: widget.style);
  }
}

TextSpan _buildFromNode(BuildContext context, html.Node node) => switch (node) {
  html.Text(:final data) => TextSpan(text: data),
  html.Element() => _buildFromElement(context, node),
  html.Node() => TextSpan(
    children: node.nodes.map((child) => _buildFromNode(context, child)).toList(),
  ),
};

TextSpan _buildFromElement(BuildContext context, html.Element element) {
  TextSpan Function(html.NodeList) any(TextSpan Function(List<TextSpan>) builder) =>
      (children) => builder(children.map((u) => _buildFromNode(context, u)).toList());

  final TextSpan Function(html.NodeList) builder = switch (element.localName) {
    "i" => any(
      (ch) => TextSpan(
        children: ch,
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
    ),
    "b" => any(
      (ch) => TextSpan(
        children: ch,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    "br" => (_) => const TextSpan(text: "\n"),
    "font" => any(
      (ch) => TextSpan(
        children: ch,
        style: TextStyle(
          color: _parseHtmlColor(element.attributes["color"]),
          fontSize: _parseHtmlFontSize(element.attributes["size"]),
        ),
      ),
    ),
    "url" || "a" => (ch) => _buildLink(context, element, ch),
    _ => any((ch) => TextSpan(children: ch)),
  };

  return builder(element.nodes);
}

TextSpan _buildLink(BuildContext context, html.Element element, html.NodeList children) {
  final href = element.attributes["href"];
  final uri = href == null ? null : Uri.tryParse(href);
  final handler = uri != null ? _linkHandlers[uri.scheme] : null;

  return TextSpan(
    text: children.map((u) => u.text).join(),
    style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
    recognizer: handler != null && uri != null
        ? (TapGestureRecognizer()
            ..onTap = () async {
              try {
                await handler(context, uri);
              } on Object catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
                }
              }
            })
        : null,
  );
}

Future<void> _handleShowInfo(BuildContext context, Uri uri) async {
  final numberStr = "${uri.host}${uri.path}";
  final match = RegExp(r"(\d+)").firstMatch(numberStr);
  final typeId = match == null ? null : int.tryParse(match.group(1)!);
  if (typeId == null || !context.mounted) return;
  await showItemDetailPage(context, typeId: typeId);
}

Future<void> _handleExternalUrl(BuildContext context, Uri uri) async {
  final didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!didLaunch) {
    throw StateError("Could not launch external URL: $uri");
  }
}

Color? _parseHtmlColor(String? value) {
  if (value == null) {
    return null;
  }

  final normalized = value.replaceFirst("#", "");
  final expanded = switch (normalized.length) {
    3 || 4 => normalized.split("").map((part) => "$part$part").join(),
    6 || 8 => normalized,
    _ => null,
  };
  if (expanded == null) {
    return null;
  }

  final parsed = int.tryParse(expanded, radix: 16);
  if (parsed == null) {
    return null;
  }

  if (expanded.length == 6) {
    return Color(parsed | 0xFF000000);
  }
  final alpha = parsed & 0xFF;
  final rgb = (parsed >> 8) & 0xFFFFFF;
  return Color((alpha << 24) | rgb);
}

double? _parseHtmlFontSize(String? value) {
  final size = value == null ? null : double.tryParse(value);
  return size == null ? null : size * 1.5;
}
