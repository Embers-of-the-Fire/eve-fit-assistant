library;

import 'package:eve_fit_assistant/native/port/api/error.dart';
import 'package:eve_fit_assistant/pages/fit/native_error/error/error.dart';
import 'package:eve_fit_assistant/pages/fit/native_error/warning/warning.dart';
import 'package:flutter/material.dart';

class ErrorDisplayDialog extends StatelessWidget {
  final List<SlotInfo> errors;

  const ErrorDisplayDialog({super.key, required this.errors});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: AlertDialog(
          title: const Text('警告'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          contentTextStyle: const TextStyle(fontSize: 18),
          content: SingleChildScrollView(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors.map(_renderError).toList(),
          )),
        ),
      );
}

Widget _renderError(SlotInfo error) => switch (error) {
      SlotInfo_Error(:final errorKey) => renderError(errorKey),
      SlotInfo_Warning(:final warningKey) => renderWarning(warningKey),
    };
