import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/features/fit_io/text_import.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

Future<void> showFitImportDialog(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const FitImportDialog(),
  );
}

class FitImportDialog extends ConsumerStatefulWidget {
  const FitImportDialog({super.key});

  @override
  ConsumerState<FitImportDialog> createState() => _FitImportDialogState();
}

class _FitImportDialogState extends ConsumerState<FitImportDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AppDialog(
      title: context.l10n.fitImportDialogTitle,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.fitImportDialogDescription),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 10,
              minLines: 8,
              decoration: InputDecoration(
                labelText: context.l10n.fitImportInputLabel,
                errorText: _error,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _handlePaste,
          child: Text(context.l10n.fitImportPasteButton),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _handleImport,
          child: Text(_busy ? context.l10n.loading : context.l10n.fitImportConfirmButton),
        ),
      ],
    ),
  );

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData("text/plain");
    if (!mounted) return;

    setState(() {
      _controller.text = data?.text?.trim() ?? "";
      _error = null;
    });
  }

  Future<void> _handleImport() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final importer = FitTextImporter(ref);
      final imported = await importer.importText(_controller.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.fitImportSuccess(fitName: imported.name))),
      );
      await context.router.push(FitRoute(fitId: imported.fitId));
    } on FitTextImportException catch (error) {
      if (!mounted) return;
      setState(() => _error = _localizeImportError(error));
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.fitImportUnknownError);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _localizeImportError(FitTextImportException error) => switch (error.code) {
    FitTextImportErrorCode.emptyInput => context.l10n.fitImportErrorEmpty,
    FitTextImportErrorCode.unsupportedFormat => context.l10n.fitImportErrorUnsupportedFormat,
    FitTextImportErrorCode.unsupportedFittingLink =>
      context.l10n.fitImportErrorUnsupportedFittingLink,
    FitTextImportErrorCode.unsupportedNativeVersion =>
      context.l10n.fitImportErrorUnsupportedNativeVersion,
    FitTextImportErrorCode.invalidNativePayload => context.l10n.fitImportErrorInvalidNativePayload,
    FitTextImportErrorCode.invalidEft => context.l10n.fitImportErrorInvalidEft,
    FitTextImportErrorCode.unknownType => context.l10n.fitImportErrorUnknownType(
      typeName: error.detail ?? "?",
    ),
    FitTextImportErrorCode.unavailableShip => context.l10n.fitImportErrorUnavailableShip(
      shipName: error.detail ?? "?",
    ),
    FitTextImportErrorCode.unavailableData => context.l10n.fitImportErrorUnavailableData,
  };
}
