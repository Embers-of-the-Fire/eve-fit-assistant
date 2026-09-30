import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/features/killmail_import/importer.dart";
import "package:eve_fit_assistant/features/killmail_import/killboard_server.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

Future<void> showKillmailImportDialog(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const KillmailImportDialog(),
  );
}

class KillmailImportDialog extends ConsumerStatefulWidget {
  const KillmailImportDialog({super.key});

  @override
  ConsumerState<KillmailImportDialog> createState() => _KillmailImportDialogState();
}

class _KillmailImportDialogState extends ConsumerState<KillmailImportDialog> {
  final TextEditingController _controller = TextEditingController();
  KillboardServer _server = KillboardServer.zkillboard;
  bool _jsonMode = false;
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
      title: context.l10n.killmailImportDialogTitle,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.killmailImportDialogDescription),
            const SizedBox(height: 12),
            if (!_jsonMode) ...[
              SegmentedButton<KillboardServer>(
                segments: [
                  for (final server in KillboardServer.values)
                    ButtonSegment(value: server, label: Text(server.host)),
                ],
                selected: {_server},
                onSelectionChanged: _busy
                    ? null
                    : (selection) => setState(() => _server = selection.first),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              maxLines: _jsonMode ? 10 : 1,
              minLines: _jsonMode ? 8 : 1,
              decoration: InputDecoration(
                labelText: _jsonMode
                    ? context.l10n.killmailImportJsonLabel
                    : context.l10n.killmailImportUrlLabel,
                errorText: _error,
                alignLabelWithHint: true,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _jsonMode = !_jsonMode;
                        _error = null;
                      }),
                child: Text(
                  _jsonMode
                      ? context.l10n.killmailImportUrlModeButton
                      : context.l10n.killmailImportJsonModeButton,
                ),
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
      final importer = KillmailImporter(ref);
      final imported = _jsonMode
          ? await importer.importFromJson(_controller.text)
          : await importer.importFromUrl(_controller.text, server: _server);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.fitImportSuccess(fitName: imported.name))),
      );
      await context.router.push(FitRoute(fitId: imported.fitId));
    } on KillmailImportException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _localizeImportError(error);
        // The WAF-blocked response cannot be retried client-side; offer the
        // paste fallback right away.
        if (error.code == KillmailImportErrorCode.fetchBlocked) {
          _jsonMode = true;
        }
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.fitImportUnknownError);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _localizeImportError(KillmailImportException error) => switch (error.code) {
    KillmailImportErrorCode.emptyInput => context.l10n.killmailImportErrorEmpty,
    KillmailImportErrorCode.invalidUrl => context.l10n.killmailImportErrorInvalidUrl,
    KillmailImportErrorCode.notFound => context.l10n.killmailImportErrorNotFound(
      killmailId: error.detail ?? "?",
    ),
    KillmailImportErrorCode.fetchBlocked => context.l10n.killmailImportErrorBlocked,
    KillmailImportErrorCode.fetchFailed => context.l10n.killmailImportErrorFetchFailed,
    KillmailImportErrorCode.invalidKillmail => context.l10n.killmailImportErrorInvalid,
    KillmailImportErrorCode.unavailableShip => context.l10n.fitImportErrorUnavailableShip(
      shipName: error.detail ?? "?",
    ),
    KillmailImportErrorCode.unavailableData => context.l10n.fitImportErrorUnavailableData,
  };
}
