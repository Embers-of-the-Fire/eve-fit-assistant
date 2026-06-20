import "dart:async";

import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

typedef AnnouncementDialogDetailCallback = FutureOr<void> Function();
typedef AnnouncementDialogPersistenceCallback =
    FutureOr<void> Function({required bool dontShowAgain});

Future<void> showAnnouncementDialog(
  BuildContext context, {
  required String title,
  required String informationText,
  AnnouncementDialogDetailCallback? onShowDetail,
  AnnouncementDialogPersistenceCallback? onPersistPreference,
  bool barrierDismissible = true,
  bool initialDontShowAgain = false,
  GlobalKey<NavigatorState>? navigatorKey,
}) => showDialog<void>(
  context: navigatorKey?.currentContext ?? context,
  barrierDismissible: barrierDismissible,
  builder: (context) => AnnouncementDialog(
    title: title,
    informationText: informationText,
    onShowDetail: onShowDetail,
    onPersistPreference: onPersistPreference,
    initialDontShowAgain: initialDontShowAgain,
  ),
);

class AnnouncementDialog extends StatefulWidget {
  const AnnouncementDialog({
    required this.title,
    required this.informationText,
    super.key,
    this.onShowDetail,
    this.onPersistPreference,
    this.initialDontShowAgain = false,
  });

  final String title;
  final String informationText;
  final AnnouncementDialogDetailCallback? onShowDetail;
  final AnnouncementDialogPersistenceCallback? onPersistPreference;
  final bool initialDontShowAgain;

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  late bool _dontShowAgain = widget.initialDontShowAgain;

  @override
  Widget build(BuildContext context) => AppDialog(
    title: widget.title,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Text(widget.informationText, style: context.theme.textTheme.bodyMedium),
            ),
          ),
          if (widget.onPersistPreference != null) ...[
            const SizedBox(height: 16),
            Theme(
              data: context.theme.copyWith(
                checkboxTheme: context.theme.checkboxTheme.copyWith(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              child: CheckboxListTile(
                value: _dontShowAgain,
                dense: true,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) => setState(() => _dontShowAgain = value ?? false),
                title: Text(context.l10n.dontShowAgain, style: context.theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      if (widget.onShowDetail != null)
        OutlinedButton(onPressed: _handleClose, child: Text(context.l10n.close)),
      ElevatedButton(
        onPressed: widget.onShowDetail == null ? _handleClose : _handleShowDetail,
        child: Text(widget.onShowDetail == null ? context.l10n.close : context.l10n.showDetails),
      ),
    ],
  );

  Future<void> _handleClose() async {
    await _persistPreference();
    if (!mounted) {
      return;
    }
    context.nav.pop();
  }

  Future<void> _handleShowDetail() async {
    final callback = widget.onShowDetail;
    if (callback == null) {
      return;
    }

    await _persistPreference();
    if (!mounted) {
      return;
    }
    context.nav.pop();
    await callback();
  }

  Future<void> _persistPreference() async {
    final callback = widget.onPersistPreference;
    if (callback == null) {
      return;
    }
    await callback(dontShowAgain: _dontShowAgain);
  }
}
