import "dart:async";
import "dart:convert";

import "package:efa_acl/efa_acl.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/fit_io/snapshot_upload_api.dart";
import "package:eve_fit_assistant/features/fit_io/text_export.dart";
import "package:eve_fit_assistant/features/fit_io/upload_request.dart";
import "package:eve_fit_assistant/features/fit_link/share_link.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
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
  FitPostSubmitResult? _uploadResult;

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
    final signedIn = ref.watch(
      platformIdentityProvider.select((identity) => identity.value != null),
    );
    // Client-side ACL gate for the upload action: the platform API enforces
    // `post:create` for real; here the button only appears for accounts whose
    // resolved permissions include it. Fail-closed while the ACL loads.
    final accountAcl = ref.watch(accountAclProvider);
    final canCreatePost = accountAcl.value?.canPostCreate() ?? false;
    final showUploadDeniedNote =
        signedIn &&
        accountAcl.hasValue &&
        !canCreatePost &&
        _selectedFormat == FitTextExportFormat.snapshot;
    final uploadResult = _uploadResult;
    return AppDialog(
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
            : uploadResult != null
            ? _buildUploadResult(context, uploadResult)
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
                      ButtonSegment<FitTextExportFormat>(
                        value: FitTextExportFormat.snapshot,
                        label: Text(context.l10n.fitExportFormatSnapshot),
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
                  if (showUploadDeniedNote) ...[
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.fitUploadNoPermission,
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: context.theme.hintColor,
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
      actions: uploadResult != null
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.close),
              ),
              FilledButton(
                onPressed: () => unawaited(_handleCopyUploadUrl(uploadResult)),
                child: Text(context.l10n.fitExportCopyLinkButton),
              ),
            ]
          : [
              if (signedIn && canCreatePost && _selectedFormat == FitTextExportFormat.snapshot)
                TextButton(
                  onPressed: _fit == null || _isExporting ? null : _handleUpload,
                  child: Text(context.l10n.fitUploadButton),
                ),
              TextButton(
                onPressed: _fit == null || _isExporting ? null : _handleCopyLink,
                child: Text(context.l10n.fitExportCopyLinkButton),
              ),
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
  }

  Widget _buildUploadResult(BuildContext context, FitPostSubmitResult result) {
    final url = FitSnapshotUploadApi.byHashUrl(result.fitHash, origin: result.origin);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.alreadyExisted
              ? context.l10n.fitUploadSuccessExisting
              : context.l10n.fitUploadSuccessNew,
          style: context.theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(context.l10n.fitUploadFitHashLabel, style: context.theme.textTheme.labelMedium),
        SelectableText(result.fitHash, style: context.theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(context.l10n.fitUploadSnapshotUrlLabel, style: context.theme.textTheme.labelMedium),
        SelectableText(url, style: context.theme.textTheme.bodySmall),
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
  }

  String _descriptionFor(FitTextExportFormat format, BuildContext context) => switch (format) {
    FitTextExportFormat.native => context.l10n.fitExportFormatNativeDescription,
    FitTextExportFormat.eft => context.l10n.fitExportFormatEftDescription,
    FitTextExportFormat.snapshot => context.l10n.fitExportFormatSnapshotDescription,
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

  Future<void> _handleUpload() async {
    final fit = _fit;
    if (fit == null) return;

    setState(() {
      _isExporting = true;
      _actionError = null;
    });
    try {
      final response = await ref.read(fitSnapshotUploadFnProvider)(
        ref,
        fitId: widget.fitId,
        fit: fit,
      );
      if (!mounted) return;
      setState(() => _uploadResult = response);
    } on FitUploadNotReadyException {
      warning("Fit upload aborted: data repository is not ready");
      if (!mounted) return;
      setState(() => _actionError = context.l10n.fitUploadErrorDataNotReady);
    } on PlatformAuthRequiredException {
      // The global onAuthRequired handler already pushed the login route.
      warning("Fit upload aborted: platform sign-in required");
      if (!mounted) return;
      setState(() => _actionError = context.l10n.fitUploadErrorUnauthorized);
    } on FitUploadException catch (e, stackTrace) {
      if (e.code == FitUploadErrorCode.unexpected) {
        fatal("Fit upload failed unexpectedly", error: e, stackTrace: stackTrace);
      } else {
        warning(
          "Fit upload rejected (${e.code.name})${e.message == null ? "" : ": ${e.message}"}"
          "${e.issues == null ? "" : "\nissues: ${jsonEncode(e.issues)}"}",
        );
      }
      if (!mounted) return;
      setState(() => _actionError = _uploadErrorMessage(e));
    } on Object catch (e, stackTrace) {
      fatal("Fit upload failed with an unexpected error", error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _actionError = context.l10n.fitUploadErrorGeneric);
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _uploadErrorMessage(FitUploadException e) => switch (e.code) {
    FitUploadErrorCode.unauthorized => context.l10n.fitUploadErrorUnauthorized,
    FitUploadErrorCode.forbidden => context.l10n.fitUploadErrorForbidden,
    FitUploadErrorCode.snapshotIncomplete => context.l10n.fitUploadErrorSnapshotIncomplete,
    FitUploadErrorCode.validationFailed => context.l10n.fitUploadErrorValidation(
      message: _describeUploadFailure(e),
    ),
    FitUploadErrorCode.unknownType => context.l10n.fitUploadErrorUnknownType(
      message: e.message ?? "",
    ),
    FitUploadErrorCode.network => context.l10n.fitUploadErrorNetwork,
    _ => context.l10n.fitUploadErrorGeneric,
  };

  String _describeUploadFailure(FitUploadException e) => [
    if (e.message case final message? when message.isNotEmpty) message,
    if (e.issues != null) jsonEncode(e.issues),
  ].join(" — ");

  Future<void> _handleCopyUploadUrl(FitPostSubmitResult result) async {
    final url = FitSnapshotUploadApi.byHashUrl(result.fitHash, origin: result.origin);
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } on Object {
      if (!mounted) return;
      setState(() => _actionError = context.l10n.fitExportClipboardError);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.fitUploadUrlCopied)));
  }

  Future<void> _handleCopyLink() async {
    final fit = _fit;
    if (fit == null) return;
    final url = const FitShareLinkBuilder().buildShareUrl(fit);
    if (url == null) {
      setState(() => _actionError = context.l10n.fitExportLinkTooLarge);
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: url));
    } on Object {
      if (!mounted) return;
      setState(() => _actionError = context.l10n.fitExportClipboardError);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.fitExportLinkCopied)));
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
      final result = await exporter.export(fit: fit, format: _selectedFormat, fitId: widget.fitId);
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
