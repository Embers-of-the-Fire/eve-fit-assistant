import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/num.dart";
import "package:flutter/material.dart";

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    super.key,
    this.content,
    this.defaultContentTextStyle,
    this.actions,
  });

  final String title;
  final Widget? content;
  final TextStyle? defaultContentTextStyle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    insetPadding: const .symmetric(vertical: 120, horizontal: 40),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    contentTextStyle: defaultContentTextStyle,
    content: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: context.mediaQuery.size.height.ensureFinite,
        maxWidth: context.mediaQuery.size.width.ensureFinite,
      ),
      child: content,
    ),
    actions: actions,
  );
}
