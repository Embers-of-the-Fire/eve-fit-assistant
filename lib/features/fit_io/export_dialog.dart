import "dart:async";
import "dart:convert";
import "package:eve_fit_assistant/compat/io.dart";

import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/features/fit_io/text_export.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:share_plus/share_plus.dart";

Future<void> showFitExportDialog(
  BuildContext context, {
  required String fitId,
  FitStorage? initialFit,
}) => showDialog<void>(
  context: context,
  builder: (context) => FitExportDialog(fitId: fitId, initialFit: initialFit),
);

class FitExportDialog extends ConsumerStatefulWidget {
  const FitExportDialog({required this.fitId, super.key, this.initialFit});

  final String fitId;
  final FitStorage? initialFit;

  @override
  ConsumerState<FitExportDialog> createState() => _FitExportDialogState();
}

class _FitExportDialogState extends ConsumerState<FitExportDialog> {
  FitTextExportFormat _selectedFormat = FitTextExportFormat.native;
  FitStorage? _fit;
  Object? _loadingError;
  String? _actionError;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _fit = widget.initialFit;
    if (_fit == null) {
      unawaited(_loadFit());
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: context.l10n.fitExportDialogTitle,
    content: SizedBox(
      width: 420,
      child: _loadingError != null
          ? Text(context.l10n.fitExportLoadError)
          : _fit == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<FitTextExportFormat>(
                  selected: <FitTextExportFormat>{_selectedFormat},
                  onSelectionChanged: _isExporting
                      ? null
                      : (selection) =>
                            _handleFormatChanged(selection.isEmpty ? null : selection.first),
                  segments: [
                    ButtonSegment<FitTextExportFormat>(
                      value: FitTextExportFormat.native,
                      label: Text(context.l10n.fitExportFormatNative),
                    ),
                    ButtonSegment<FitTextExportFormat>(
                      value: FitTextExportFormat.eft,
                      label: Text(context.l10n.fitExportFormatEft),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _descriptionFor(_selectedFormat, context),
                  style: context.theme.textTheme.bodyMedium,
                ),
                if (_selectedFormat == FitTextExportFormat.eft) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.fitExportLossyWarning,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.error,
                    ),
                  ),
                ],
                if (_actionError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _actionError!,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    ),
    actions: [
      TextButton(
        onPressed: _fit == null || _isExporting ? null : _handleShare,
        child: Text(context.l10n.share),
      ),
      TextButton(
        onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: _fit == null || _isExporting ? null : _handleCopy,
        child: Text(_isExporting ? context.l10n.loading : context.l10n.copy),
      ),
    ],
  );

  String _descriptionFor(FitTextExportFormat format, BuildContext context) => switch (format) {
    FitTextExportFormat.native => context.l10n.fitExportFormatNativeDescription,
    FitTextExportFormat.eft => context.l10n.fitExportFormatEftDescription,
  };

  void _handleFormatChanged(FitTextExportFormat? format) {
    if (format == null) return;
    setState(() {
      _selectedFormat = format;
      _actionError = null;
    });
  }

  Future<void> _loadFit() async {
    try {
      final path = File(FitStorage.fitStoragePathForId(widget.fitId));
      final text = await path.readAsString();
      final fit = decodeFitStorage(jsonDecode(text) as Map<String, dynamic>).fit;
      if (!mounted) return;
      setState(() => _fit = fit);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadingError = error);
    }
  }

  Future<void> _handleCopy() async {
    await _runExportAction((fit, result) async {
      await Clipboard.setData(ClipboardData(text: result.text));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.fitExportCopied)));
    }, onErrorMessage: context.l10n.fitExportClipboardError);
  }

  Future<void> _handleShare() async {
    await _runExportAction((fit, result) async {
      await SharePlus.instance.share(ShareParams(text: result.text, subject: fit.metadata.name));
    }, onErrorMessage: context.l10n.fitExportShareError);
  }

  Future<void> _runExportAction(
    Future<void> Function(FitStorage fit, FitTextExportResult result) action, {
    required String onErrorMessage,
  }) async {
    final fit = _fit;
    if (fit == null) return;

    setState(() {
      _isExporting = true;
      _actionError = null;
    });
    try {
      final exporter = FitTextExporter(ref);
      final result = await exporter.export(fit: fit, format: _selectedFormat);
      await action(fit, result);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _actionError = onErrorMessage);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}
