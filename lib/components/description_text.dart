import "dart:async";

import "package:eve_fit_assistant/pages/item-detail/page.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:html/dom.dart" as html;
import "package:html/parser.dart" as html_parser;
import "package:url_launcher/url_launcher.dart";

class DescriptionText extends StatefulWidget {
  const DescriptionText({required this.text, super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  State<DescriptionText> createState() => _DescriptionTextState();
}

class _DescriptionTextState extends State<DescriptionText>
    with AutomaticKeepAliveClientMixin<DescriptionText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    _disposeRecognizers();

    final normalizedText = widget.text.replaceAllMapped(
      RegExp("<url=([^>]+)>"),
      (match) => '<url href="${match.group(1)}">',
    );
    final fragment = html_parser.parseFragment("<div>$normalizedText</div>");

    return SelectableText.rich(_buildFromNode(context, fragment), style: widget.style);
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TextSpan _buildFromNode(BuildContext context, html.Node node) => switch (node) {
    html.Text(:final data) => TextSpan(text: data),
    html.Element() => _buildFromElement(context, node),
    html.Node() => TextSpan(
      children: node.nodes.map((child) => _buildFromNode(context, child)).toList(),
    ),
  };

  TextSpan _buildFromElement(BuildContext context, html.Element element) {
    List<TextSpan> buildChildren() =>
        element.nodes.map((child) => _buildFromNode(context, child)).toList();

    final builder = switch (element.localName) {
      "i" => () => TextSpan(
        children: buildChildren(),
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
      "b" => () => TextSpan(
        children: buildChildren(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      "br" => () => const TextSpan(text: "\n"),
      "font" => () => TextSpan(
        children: buildChildren(),
        style: TextStyle(
          color: _parseHtmlColor(element.attributes["color"]),
          fontSize: _parseHtmlFontSize(element.attributes["size"]),
        ),
      ),
      "url" => () => TextSpan(
        children: buildChildren(),
        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
        recognizer: _registerRecognizer(
          element.attributes["href"] == null
              ? null
              : () => _openExternalUrl(element.attributes["href"]!),
        ),
      ),
      "a" => () => TextSpan(
        children: buildChildren(),
        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
        recognizer: _registerRecognizer(
          element.attributes["href"] == null ? null : () => _openShowInfo(context, element),
        ),
      ),
      _ => () => TextSpan(children: buildChildren()),
    };

    return builder();
  }

  TapGestureRecognizer? _registerRecognizer(VoidCallback? onTap) {
    if (onTap == null) {
      return null;
    }

    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  Future<void> _openExternalUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openShowInfo(BuildContext context, html.Element element) async {
    final href = element.attributes["href"];
    final typeId = href == null ? null : int.tryParse(href.replaceFirst("showinfo:", ""));
    if (typeId == null || !context.mounted) {
      return;
    }

    await showItemDetailPage(context, typeId: typeId);
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

    return Color(expanded.length == 6 ? parsed | 0xFF000000 : parsed);
  }

  double? _parseHtmlFontSize(String? value) {
    final size = value == null ? null : double.tryParse(value);
    return size == null ? null : size * 1.5;
  }
}
