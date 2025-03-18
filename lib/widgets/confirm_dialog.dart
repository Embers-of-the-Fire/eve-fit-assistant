import 'package:eve_fit_assistant/widgets/dialog.dart';
import 'package:flutter/material.dart';

Future<void> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String description,
  String? warning,
  required void Function() onConfirm,
}) async {
  await showDialog(
    context: context,
    builder: (context) => ConfirmDialog(
      title: title,
      description: description,
      warning: warning,
      onConfirm: onConfirm,
    ),
  );
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String description;
  final String? warning;
  final void Function() onConfirm;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.description,
    this.warning,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => AppDialog(
        title: title,
        content: Text.rich(TextSpan(children: [
          TextSpan(text: description),
          if (warning != null)
            TextSpan(text: '\n\n$warning', style: const TextStyle(color: Colors.red))
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          TextButton(
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop();
              },
              child: const Text('确认')),
        ],
      );
}
