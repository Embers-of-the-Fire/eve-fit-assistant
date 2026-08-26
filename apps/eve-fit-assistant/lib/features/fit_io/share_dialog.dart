import "dart:async";
import "dart:convert";

import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/features/fit_io/share_operation.dart";
import "package:eve_fit_assistant/features/fit_io/snapshot_upload_api.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

Future<void> showFitShareDialog(
  BuildContext context, {
  required String fitId,
  FitStorage? initialFit,
}) => showDialog<void>(
  context: context,
  builder: (context) => FitShareDialog(fitId: fitId, initialFit: initialFit),
);

/// The dedicated "share" dialog: publishes the fit to the platform via
/// [FitShareOperation] and redirects the user to the resulting post page.
/// Entry points are gated by [fitShareEligibilityProvider], so this dialog
/// assumes the account is allowed to publish.
class FitShareDialog extends ConsumerStatefulWidget {
  const FitShareDialog({required this.fitId, super.key, this.initialFit});

  final String fitId;
  final FitStorage? initialFit;

  @override
  ConsumerState<FitShareDialog> createState() => _FitShareDialogState();
}

class _FitShareDialogState extends ConsumerState<FitShareDialog> {
  FitStorage? _fit;
  Object? _loadingError;
  String? _actionError;
  bool _isSharing = false;
  FitPostSubmitResult? _shareResult;

  @override
  void initState() {
    super.initState();
    _fit = widget.initialFit;
    if (_fit == null) {
      unawaited(_loadFit());
    }
  }

  @override
  Widget build(BuildContext context) {
    final fit = _fit;
    final shareResult = _shareResult;
    return AppDialog(
      title: context.l10n.fitShareDialogTitle,
      content: SizedBox(
        width: 420,
        child: _loadingError != null
            ? Text(context.l10n.fitExportLoadError)
            : fit == null
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : shareResult != null
            ? _buildShareResult(context, shareResult)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fit.metadata.name, style: context.theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(context.l10n.fitShareDescription, style: context.theme.textTheme.bodyMedium),
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
      actions: shareResult != null
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.close),
              ),
              TextButton(
                onPressed: () => unawaited(_handleCopyShareLink(shareResult)),
                child: Text(context.l10n.fitExportCopyLinkButton),
              ),
              FilledButton(
                onPressed: () => unawaited(_handleOpenPost(shareResult)),
                child: Text(context.l10n.fitShareOpenPost),
              ),
            ]
          : [
              TextButton(
                onPressed: _isSharing ? null : () => Navigator.of(context).pop(),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: fit == null || _isSharing ? null : _handleShare,
                child: Text(_isSharing ? context.l10n.loading : context.l10n.fitShareButton),
              ),
            ],
    );
  }

  Widget _buildShareResult(BuildContext context, FitPostSubmitResult result) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        result.alreadyExisted
            ? context.l10n.fitShareSuccessExisting
            : context.l10n.fitShareSuccessNew,
        style: context.theme.textTheme.bodyMedium,
      ),
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
  );

  Future<void> _loadFit() async {
    try {
      final store = ref.read(fitsDocStoreProvider);
      final text = await store.read("${widget.fitId}.json");
      if (text == null) {
        throw StateError("Fit file does not exist: ${widget.fitId}");
      }
      final fit = decodeFitStorage(jsonDecode(text) as Map<String, dynamic>).fit;
      if (!mounted) return;
      setState(() => _fit = fit);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _loadingError = error);
    }
  }

  Future<void> _handleShare() async {
    final fit = _fit;
    if (fit == null) return;

    setState(() {
      _isSharing = true;
      _actionError = null;
    });
    try {
      final result = await const FitShareOperation().share(ref, fitId: widget.fitId, fit: fit);
      if (!mounted) return;
      setState(() => _shareResult = result);
    } on Object catch (error, stackTrace) {
      logFitShareFailure(error, stackTrace);
      if (!mounted) return;
      setState(() => _actionError = describeFitShareError(context.l10n, error));
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _handleOpenPost(FitPostSubmitResult result) =>
      const FitShareOperation().openPost(ref, result.postUrl);

  Future<void> _handleCopyShareLink(FitPostSubmitResult result) async {
    try {
      await Clipboard.setData(ClipboardData(text: result.postUrl));
    } on Object {
      if (!mounted) return;
      setState(() => _actionError = context.l10n.fitExportClipboardError);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.fitShareLinkCopied)));
  }
}
