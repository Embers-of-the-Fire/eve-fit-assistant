import 'package:eve_fit_assistant/native/glue/native_slot.dart';
import 'package:eve_fit_assistant/native/port/api/error.dart';
import 'package:eve_fit_assistant/pages/fit/native_error/error_display.dart';
import 'package:flutter/material.dart';

enum ErrorLevel {
  warning,
  error,
}

class NativeErrorTrigger extends StatelessWidget {
  final List<SlotInfo> errors;

  const NativeErrorTrigger({super.key, required this.errors});

  @override
  Widget build(BuildContext context) {
    ErrorLevel errState = ErrorLevel.warning;
    for (final err in errors) {
      if (err.isError) {
        errState = ErrorLevel.error;
        break;
      }
    }

    final errorIcon = switch (errState) {
      ErrorLevel.error => const Icon(Icons.error_outline, color: Colors.red),
      ErrorLevel.warning => const Icon(Icons.error_outline, color: Colors.orange),
    };

    return Ink(
      decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(50))),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(50)),
        onTap: () => showDialog(
          context: context,
          builder: (context) => ErrorDisplayDialog(errors: errors),
        ),
        child: Container(
          padding: const EdgeInsets.all(5),
          child: errorIcon,
        ),
      ),
    );
  }
}
