import 'package:flutter/material.dart';

class AppDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final TextStyle? contentTextStyle;
  final List<Widget>? actions;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.contentTextStyle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        insetPadding: const EdgeInsets.symmetric(vertical: 120, horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentTextStyle: contentTextStyle,
        content: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: content),
        actions: actions,
      );
}
