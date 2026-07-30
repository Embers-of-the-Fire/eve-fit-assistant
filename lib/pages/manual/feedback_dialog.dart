import "dart:async";

import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/features/manual/repository/manual_feedback_api.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

/// Show the manual feedback dialog: an issue report about [docTitle] when
/// [kind] is [ManualFeedbackKind.report], or a general question otherwise.
Future<void> showManualFeedbackDialog(
  BuildContext context, {
  required ManualFeedbackKind kind,
  String? docId,
  String? docTitle,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ManualFeedbackDialog(kind: kind, docId: docId, docTitle: docTitle),
);

/// App-bar action that opens the manual question dialog.
class ManualQuestionAction extends StatelessWidget {
  const ManualQuestionAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.help_outline),
    tooltip: context.l10n.manualActionQuestionTooltip,
    onPressed: () =>
        unawaited(showManualFeedbackDialog(context, kind: ManualFeedbackKind.question)),
  );
}

class _ManualFeedbackDialog extends StatefulWidget {
  const _ManualFeedbackDialog({required this.kind, this.docId, this.docTitle});

  final ManualFeedbackKind kind;
  final String? docId;
  final String? docTitle;

  @override
  State<_ManualFeedbackDialog> createState() => _ManualFeedbackDialogState();
}

class _ManualFeedbackDialogState extends State<_ManualFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  final _descriptionCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  bool _submitting = false;

  final _api = ManualFeedbackApi();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.docTitle ?? "");
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: switch (widget.kind) {
      ManualFeedbackKind.report => context.l10n.manualReportDialogTitle,
      ManualFeedbackKind.question => context.l10n.manualQuestionDialogTitle,
    },
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildField(
                context.l10n.reportFieldTitle,
                _titleCtrl,
                hint: context.l10n.reportFieldTitleHint,
                required: context.l10n.reportFieldTitleRequired,
              ),
              const SizedBox(height: 16),
              _buildField(
                context.l10n.manualFeedbackFieldDescription,
                _descriptionCtrl,
                minLines: 4,
                hint: context.l10n.manualFeedbackFieldDescriptionHint,
                required: context.l10n.manualFeedbackFieldDescriptionRequired,
              ),
              const SizedBox(height: 16),
              _buildField(
                context.l10n.reportFieldContact,
                _contactCtrl,
                hint: context.l10n.reportFieldContactHint,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        child: Text(context.l10n.reportDialogClose),
      ),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : Text(context.l10n.reportSubmit),
      ),
    ],
  );

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    int minLines = 1,
    String? hint,
    String? required,
  }) => TextFormField(
    controller: ctrl,
    minLines: minLines,
    maxLines: minLines == 1 ? 1 : null,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      if (required != null && (value == null || value.trim().isEmpty)) {
        return required;
      }
      return null;
    },
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final locale = Localizations.localeOf(context).languageCode;

    await _api.submit(
      ManualFeedback(
        kind: widget.kind,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        contact: _contactCtrl.text.trim(),
        locale: locale.startsWith("zh") ? "zh" : "en",
        docId: widget.docId,
        docTitle: widget.docTitle,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    unawaited(_showSuccessDialog());
  }

  Future<void> _showSuccessDialog() => showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      title: context.l10n.manualFeedbackSuccessTitle,
      content: SizedBox(width: 400, child: Text(context.l10n.manualFeedbackSuccessBody)),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(context.l10n.reportDialogClose),
        ),
      ],
    ),
  );
}
